# %% Imports
import json
import logging
from pathlib import Path

from uvloop import run

from kakarot_scripts.constants import EVM_ADDRESS, NETWORK, RPC_CLIENT, NetworkType
from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.kakarot import deploy_and_fund_evm_address
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_contract as get_solidity_contract
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.starknet import call_contract
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.starknet import (
    get_starknet_account,
    invoke,
    register_lazy_account,
    remove_lazy_account,
)
from tests.utils.helpers import int_to_string

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %%
async def deploy_dualvm_tokens() -> None:
    # %% Setup

    # The lazy execution must be done before we check the deployments succeeded, as the l2 contracts
    # need to be deployed first
    account = await get_starknet_account()

    # Remove lazy account before we check the deployments succeeded, as the l2 contracts
    # need to be deployed sequentially.
    remove_lazy_account(account.address)

    kakarot_address = get_starknet_deployments()["kakarot"]
    evm_deployments = get_evm_deployments()

    file_path = Path(NETWORK["token_addresses_file"])
    if not file_path.exists():
        raise ValueError(
            f"Token addresses file not found for network: {NETWORK['name']}"
        )

    tokens = json.loads(file_path.read_text())
    kakarot_native_token = (
        await call_contract("kakarot", "get_native_token")
    ).native_token_address
    kakarot_native_token_name = int_to_string(
        (await call_contract("ERC20", "name", address=kakarot_native_token)).name
    )
    kakarot_native_token_symbol = int_to_string(
        (await call_contract("ERC20", "symbol", address=kakarot_native_token)).symbol
    )

    # %% Deploy DualVM Tokens
    for token in tokens:

        # Skip if entry is not a token
        if "l2_token_address" not in token:
            logger.info("Skipping %s: missing l2_token_address", token["name"])
            continue

        l2_token_address = int(token["l2_token_address"], 16)

        # Skip native token
        if (
            token["name"] == kakarot_native_token_name
            and token["symbol"] == kakarot_native_token_symbol
        ):
            logger.info("ℹ️ Skipping %s: native token", token["name"])
            continue

        # Check if DualVM token is a deployed contract on Starknet
        if dualvm_token_deployment := evm_deployments.get(token["name"]):
            try:
                await RPC_CLIENT.get_class_hash_at(
                    dualvm_token_deployment["starknet_address"]
                )
                token_contract = await get_solidity_contract(
                    "CairoPrecompiles",
                    "DualVmToken",
                    evm_deployments[token["name"]]["address"],
                )
                assert await token_contract.kakarot() == kakarot_address
                logger.info("Skipping %s: already deployed on Starknet", token["name"])
                continue
            except Exception:
                pass

        # DualVM token is not deployed, deploy one
        # Check if the L2 token exists, if not deploy one
        try:
            await RPC_CLIENT.get_class_hash_at(l2_token_address)
        except Exception as e:
            if NETWORK["type"] != NetworkType.DEV:
                raise ValueError(
                    f"Starknet token for {token['name']} doesn't exist on L2"
                ) from e

            logger.info(f"⏳ {token['name']} doesn't exist on Starknet, deploying...")
            owner = await get_starknet_account()
            l2_token_address = await deploy_starknet(
                "StarknetToken",
                token["name"],
                token["symbol"],
                token["decimals"],
                int(2**256 - 1),
                owner.address,
            )

        if token["name"] not in evm_deployments:
            contract = await deploy_kakarot(
                "CairoPrecompiles", "DualVmToken", kakarot_address, l2_token_address
            )
            await invoke(
                "kakarot",
                "set_authorized_cairo_precompile_caller",
                int(contract.address, 16),
                True,
            )
            evm_deployments[token["name"]] = {
                "address": int(contract.address, 16),
                "starknet_address": contract.starknet_address,
            }

        token_contract = await get_solidity_contract(
            "CairoPrecompiles", "DualVmToken", evm_deployments[token["name"]]["address"]
        )
        assert await token_contract.starknetToken() == l2_token_address
        assert await token_contract.name() == token["name"]
        assert await token_contract.symbol() == token["symbol"]
        assert await token_contract.decimals() == token["decimals"]

    # %% Save deployments
    dump_evm_deployments(evm_deployments)
    logger.info("Finished processing all DualVM tokens")
    register_lazy_account(account.address)


# %% Run
async def main() -> None:
    try:
        await RPC_CLIENT.get_class_hash_at(get_starknet_deployments()["kakarot"])
    except Exception:
        logger.error("❌ Kakarot is not deployed, exiting...")
        return

    await deploy_and_fund_evm_address(
        EVM_ADDRESS, amount=100 if NETWORK["type"] is NetworkType.DEV else 0.01
    )

    await deploy_dualvm_tokens()


def main_sync() -> None:
    run(main())


# %%
if __name__ == "__main__":
    main_sync()
