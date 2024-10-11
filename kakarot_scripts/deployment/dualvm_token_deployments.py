# %% Imports
import json
import logging
from typing import List, Dict, Any

from uvloop import run

from kakarot_scripts.constants import EVM_ADDRESS, NETWORK, RPC_CLIENT, TOKEN_ADDRESSES_DIR, NetworkType
from kakarot_scripts.utils.kakarot import (
    deploy as deploy_kakarot,
    deploy_and_fund_evm_address,
    get_deployments as get_evm_deployments,
    dump_deployments as dump_evm_deployments,
)
from kakarot_scripts.utils.starknet import (
    deploy as deploy_starknet,
    get_class_hash_at,
    get_deployments as get_starknet_deployments,
    get_contract as get_contract_starknet,
    get_starknet_account,
    invoke,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
# %%

async def deploy_starknet_token(owner_address: str) -> Any:
    address = await deploy_starknet("StarknetToken", int(1e18), owner_address)
    return get_contract_starknet("StarknetToken", address=address)

async def deploy_dualvm_token(kakarot_address: str, starknet_token_address: str, deployer_account: Any = None) -> Any:
    dual_vm_token = await deploy_kakarot(
        "CairoPrecompiles",
        "DualVmToken",
        kakarot_address,
        starknet_token_address,
        caller_eoa=deployer_account,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(dual_vm_token.address, 16),
        True,
    )
    return dual_vm_token

async def deploy_dualvm_tokens() -> None:
    # %% Deploy DualVM Tokens
    kakarot = get_starknet_deployments()["kakarot"]
    evm_deployments = get_evm_deployments()
    tokens = await get_tokens(NETWORK)

    for token in tokens:
        token_name = token["name"]
        if token_name not in evm_deployments:
            await deploy_new_token(token_name, token, kakarot, evm_deployments)
        else:
            await verify_and_update_existing_token(token_name, token, kakarot, evm_deployments)

    logger.info("Finished processing all tokens")
    dump_evm_deployments(evm_deployments)
    logger.info("Updated EVM deployments have been saved")
    # %%


async def get_tokens(network) -> List[Dict[str, Any]]:
    """
        Gets the list of tokens for a given network.
        If in dev mode, will return the sepolia token list.
    """
    if network["type"] == NetworkType.DEV:
        return await load_tokens("sepolia")
    if network["name"] not in ("mainnet", "sepolia"):
        raise ValueError(f"No known token addresses for network: {network['name']}")
    return await load_tokens(network["name"])

async def load_tokens(network_name: str) -> List[Dict[str, Any]]:
    file_name = network_name.replace("starknet-", "")
    file_path = TOKEN_ADDRESSES_DIR / f"{file_name}.json"
    return json.loads(file_path.read_text())


async def deploy_new_token(token_name: str, token: Dict[str, Any], kakarot: str, evm_deployments: Dict[str, Any]) -> None:
    """
        Deploys a new DualVMToken for a corresponding Starknet ERC20 token.
    """
    l2_token_address = await ensure_starknet_token(token_name, token)
    contract = await deploy_dualvm_token(kakarot, l2_token_address)
    evm_deployments[token_name] = {
        "address": int(contract.address, 16),
        "starknet_address": contract.starknet_address,
    }
    logger.info(f"Deployed new DualVMToken for {token_name} at address {contract.address}")

async def verify_and_update_existing_token(token_name: str, token: Dict[str, Any], kakarot: str, evm_deployments: Dict[str, Any]) -> None:
    """
        Given an existing DualVMToken, verifies it is _actually_ deployed. If not, deploys a new one.
    """
    dualvm_token_address = evm_deployments[token_name]["starknet_address"]
    if not await get_class_hash_at(dualvm_token_address):
        l2_token_address = await ensure_starknet_token(token_name, token)
        contract = await deploy_dualvm_token(kakarot, l2_token_address)
        evm_deployments[token_name] = {
            "address": int(contract.address, 16),
            "starknet_address": contract.starknet_address,
        }
        logger.info(f"Deployed new DualVMToken for {token_name} at address {contract.address}")
    else:
        logger.info(f"Existing DualVMToken for {token_name} is valid")

async def ensure_starknet_token(token_name: str, token: Dict[str, Any]) -> str:
    """
        Ensures a Starknet ERC20 token exists for a given dualVM token.
        If not, deploys a new one in dev networks, or returns the starknet address in production networks.
    """
    if NETWORK["type"] == NetworkType.DEV:
        owner = await get_starknet_account()
        starknet_token = await deploy_starknet_token(owner.address)
        token["l2_token_address"] = starknet_token.address
        logger.info(f"Deployed new Starknet token for {token_name} at address {starknet_token.address}")
    else:
        logger.info(f"Using existing Starknet token for {token_name} at address {token['l2_token_address']}")
    return token["l2_token_address"]

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

if __name__ == "__main__":
    main_sync()

# %%
