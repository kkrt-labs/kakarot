# %% Imports
import json
import logging
from pathlib import Path
from typing import Any, Dict, List

from uvloop import run

from kakarot_scripts.constants import EVM_ADDRESS, NETWORK, RPC_CLIENT, NetworkType
from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.kakarot import deploy_and_fund_evm_address
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_contract as get_solidity_contract
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.starknet import call_contract
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import execute_calls
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.starknet import (
    get_starknet_account,
    invoke,
    register_lazy_account,
    remove_lazy_account,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %%
async def deploy_dualvm_tokens() -> None:
    # %% Deploy DualVM Tokens

    # The lazy execution must be done before we check the deployments succeeded, as the l2 contracts
    # need to be deployed first
    register_lazy_account(await get_starknet_account())

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

    # Filter tokens based on deployment criteria
    tokens_to_deploy: List[Dict[str, Any]] = []
    for token in tokens:
        token_name = token["name"]

        # Skip tokens without L2 address
        if "l2_token_address" not in token:
            logger.info("Skipping %s: missing l2_token_address", token_name)
            continue

        l2_token_address = int(token["l2_token_address"], 16)

        # Skip native token
        if l2_token_address == kakarot_native_token:
            logger.info("Skipping %s: native token", token_name)
            continue

        # Skip if token is already deployed
        if dualvm_token_deployment := evm_deployments.get(token_name):
            try:
                await RPC_CLIENT.get_class_hash_at(
                    dualvm_token_deployment["starknet_address"]
                )
                logger.info("Skipping %s: already deployed on Starknet", token_name)
                continue
            except Exception:
                # Token not deployed, include it in candidates
                pass

        tokens_to_deploy.append(token)

    # Deploy tokens
    for token in tokens_to_deploy:
        l2_token_address = int(token["l2_token_address"], 16)
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
            token["l2_token_address"] = hex(l2_token_address)

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

    await execute_calls()
    dump_evm_deployments(evm_deployments)
    remove_lazy_account(await get_starknet_account())

    # Check deployments
    # Reload evm deployments to get the proper formatting of addresses.
    evm_deployments = get_evm_deployments()
    for token in tokens_to_deploy:
        token_contract = await get_solidity_contract(
            "CairoPrecompiles", "DualVmToken", evm_deployments[token["name"]]["address"]
        )
        assert await token_contract.starknetToken() == int(
            token["l2_token_address"], 16
        )
        assert await token_contract.kakarot() == kakarot_address
        assert await token_contract.name() == token["name"]
        assert await token_contract.symbol() == token["symbol"]
        assert await token_contract.decimals() == token["decimals"]
    logger.info("Finished processing all DualVM tokens")


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
