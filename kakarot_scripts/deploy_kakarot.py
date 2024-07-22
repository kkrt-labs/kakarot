# %% Imports
import logging
from asyncio import run

from kakarot_scripts.constants import (
    ARACHNID_PROXY_DEPLOYER,
    ARACHNID_PROXY_SIGNED_TX,
    BLOCK_GAS_LIMIT,
    COINBASE,
    CREATEX_DEPLOYER,
    CREATEX_SIGNED_TX,
    DECLARED_CONTRACTS,
    DEFAULT_GAS_PRICE,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    MULTICALL3_DEPLOYER,
    MULTICALL3_SIGNED_TX,
    NETWORK,
    RPC_CLIENT,
    NetworkType,
)
from kakarot_scripts.utils.kakarot import deploy_contract as deploy_evm
from kakarot_scripts.utils.kakarot import deploy_with_presigned_tx
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.starknet import declare
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import (
    dump_declarations,
    dump_deployments,
    get_declarations,
)
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.starknet import get_starknet_account, invoke, upgrade

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Declarations
    account = await get_starknet_account()
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    class_hash = {
        contract["contract_name"]: await declare(contract)
        for contract in DECLARED_CONTRACTS
    }
    dump_declarations(class_hash)

    # %% Deployments
    class_hash = get_declarations()
    starknet_deployments = get_starknet_deployments()
    evm_deployments = get_evm_deployments()
    freshly_deployed = False

    if starknet_deployments.get("kakarot") and NETWORK["type"] is not NetworkType.DEV:
        logger.info("ℹ️  Kakarot already deployed, checking version.")
        deployed_class_hash = await RPC_CLIENT.get_class_hash_at(
            starknet_deployments["kakarot"]["address"]
        )
        if deployed_class_hash != class_hash["kakarot"]:
            await invoke("kakarot", "upgrade", class_hash["kakarot"])
            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                class_hash["account_contract"],
            )
            await invoke(
                "kakarot",
                "set_cairo1_helpers_class_hash",
                class_hash["Cairo1Helpers"],
            )
        else:
            logger.info("✅ Kakarot already up to date.")
    else:
        starknet_deployments["kakarot"] = await deploy_starknet(
            "kakarot",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            COINBASE,
            BLOCK_GAS_LIMIT,
        )
        freshly_deployed = True

    if NETWORK["type"] is NetworkType.STAGING:
        starknet_deployments["EVM"] = await upgrade(
            "EVM",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            COINBASE,
            BLOCK_GAS_LIMIT,
        )
        starknet_deployments["Counter"] = await upgrade("Counter")
        starknet_deployments["MockPragmaOracle"] = await upgrade("MockPragmaOracle")

    if NETWORK["type"] is NetworkType.DEV:
        starknet_deployments["EVM"] = await deploy_starknet(
            "EVM",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            COINBASE,
            BLOCK_GAS_LIMIT,
        )
        starknet_deployments["Counter"] = await deploy_starknet("Counter")
        starknet_deployments["MockPragmaOracle"] = await deploy_starknet(
            "MockPragmaOracle"
        )

    dump_deployments(starknet_deployments)

    if EVM_ADDRESS:
        logger.info(f"ℹ️  Found default EVM address {EVM_ADDRESS}")
        from kakarot_scripts.utils.kakarot import get_eoa

        amount = (
            0.02
            if NETWORK["type"] is not (NetworkType.DEV or NetworkType.STAGING)
            else 100
        )
        await get_eoa(amount=amount)

    # Set the base fee if freshly deployed
    if freshly_deployed:
        await invoke("kakarot", "set_base_fee", DEFAULT_GAS_PRICE)

    # Deploy the solidity contracts
    weth = await deploy_evm("WETH", "WETH9")
    evm_deployments["WETH"] = {
        "address": int(weth.address, 16),
        "starknet_address": weth.starknet_address,
    }

    # Pre-EIP155 deployments
    evm_deployments["Multicall3"] = await deploy_with_presigned_tx(
        MULTICALL3_DEPLOYER, MULTICALL3_SIGNED_TX, name="Multicall3"
    )
    evm_deployments["Arachnid_Proxy"] = await deploy_with_presigned_tx(
        ARACHNID_PROXY_DEPLOYER, ARACHNID_PROXY_SIGNED_TX, name="Arachnid Proxy"
    )
    evm_deployments["CreateX"] = await deploy_with_presigned_tx(
        CREATEX_DEPLOYER, CREATEX_SIGNED_TX, amount=0.3, name="CreateX"
    )
    dump_evm_deployments(evm_deployments)


# %% Run
if __name__ == "__main__":
    run(main())
