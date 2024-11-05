# %% Imports
import json
import logging
from typing import Any, Dict, List

from uvloop import run

from kakarot_scripts.constants import (
    EVM_ADDRESS,
    NETWORK,
    RPC_CLIENT,
    TOKEN_ADDRESSES_DIR,
    NetworkType,
)
from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.kakarot import deploy_and_fund_evm_address
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.starknet import call_contract
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import execute_calls, get_class_hash_at
from kakarot_scripts.utils.starknet import get_contract as get_contract_starknet
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
    kakarot = get_starknet_deployments()["kakarot"]
    kakarot_native_token = (
        await call_contract("kakarot", "get_native_token")
    ).native_token_address
    evm_deployments = get_evm_deployments()
    tokens = get_tokens_list()
    for token in tokens:
        if int(token["l2_token_address"], 16) == kakarot_native_token:
            logger.info(f"Skipping {token['name']} as it is the native token")
            continue
        if token["name"] not in evm_deployments:
            await deploy_new_token(token, kakarot, evm_deployments)
        else:
            is_deployed = await check_dualvm_token_deployment(token, evm_deployments)
            if not is_deployed:
                await deploy_new_token(token, kakarot, evm_deployments)

    logger.info("Finished processing all DualVM tokens")
    dump_evm_deployments(evm_deployments)
    # %%


def get_tokens_list() -> List[Dict[str, Any]]:
    """
    Get the list of tokens for a given network.
    If in dev mode, will return the sepolia token list.
    """
    if NETWORK["type"] == NetworkType.DEV:
        return load_tokens("sepolia")

    return load_tokens(NETWORK["name"])


def load_tokens(network_name: str) -> List[Dict[str, Any]]:
    """
    Load the list of tokens for a given network, using the starknet.io token list.
    Filters out entries without an l2_token_address (which are not bridged tokens).
    """
    file_path = TOKEN_ADDRESSES_DIR / f"{network_name}.json"
    if not file_path.exists():
        raise ValueError(f"No known token addresses for network: {network_name}")

    tokens = json.loads(file_path.read_text())
    return [token for token in tokens if "l2_token_address" in token]


async def deploy_new_token(
    token: Dict[str, Any],
    kakarot_address: str,
    evm_deployments: Dict[str, Any],
) -> None:
    """
    Deploy a new DualVMToken for a corresponding Starknet ERC20 token.
    """
    token_name = token["name"]
    l2_token_address = await get_starknet_token(token)
    contract = await deploy_kakarot(
        "CairoPrecompiles",
        "DualVmToken",
        kakarot_address,
        int(l2_token_address, 16),
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(contract.address, 16),
        True,
    )
    evm_deployments[token_name] = {
        "address": int(contract.address, 16),
        "starknet_address": contract.starknet_address,
    }
    logger.info(
        f"Deployed new DualVMToken for {token_name} at address {contract.address}"
    )


async def check_dualvm_token_deployment(
    token: Dict[str, Any],
    evm_deployments: Dict[str, Any],
) -> bool:
    """
    Given an existing DualVMToken, verifies it is _actually_ deployed.
    """
    token_name = token["name"]
    dualvm_token_address = evm_deployments[token_name]["starknet_address"]
    if await get_class_hash_at(dualvm_token_address):
        return True
    else:
        return False


async def get_starknet_token(token: Dict[str, Any]) -> str:
    """
    Return the starknet address of the ERC20 token corresponding to a given dualVM token.
    If it doesn't exist yet, deploys a new one in dev networks.
    """
    token_name = token["name"]
    if NETWORK["type"] == NetworkType.DEV:
        try:
            RPC_CLIENT.get_class_hash_at(token["l2_token_address"])
            logger.info(
                f"Using existing Starknet token for {token_name} at address {token['l2_token_address']}"
            )
        except Exception:
            starknet_token = await deploy_starknet_token()
            token["l2_token_address"] = f"0x{starknet_token.address:064x}"
            logger.info(
                f"Deployed new Starknet token for {token_name} at address {token['l2_token_address']}"
            )
    else:
        logger.info(
            f"Using existing Starknet token for {token_name} at address {token['l2_token_address']}"
        )
    return token["l2_token_address"]


async def deploy_starknet_token() -> Any:
    owner = await get_starknet_account()
    address = await deploy_starknet(
        "StarknetToken", "MyToken", "MTK", int(1e18), owner.address
    )
    return get_contract_starknet("StarknetToken", address=address)


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

    account = await get_starknet_account()
    register_lazy_account(account)
    await deploy_dualvm_tokens()
    await execute_calls()
    remove_lazy_account(account.address)


def main_sync() -> None:
    run(main())


# %%
if __name__ == "__main__":
    main_sync()
