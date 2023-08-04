# %% Imports
import logging
from asyncio import run

from scripts.constants import (
    COMPILED_CONTRACTS,
    DEPLOY_FEE,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
)
from scripts.utils.starknet import (
    declare,
    deploy,
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_starknet_account,
    invoke,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Declarations
    account = await get_starknet_account()
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    class_hash = {
        contract["contract_name"]: await declare(contract["contract_name"])
        for contract in COMPILED_CONTRACTS
    }
    dump_declarations(class_hash)

    # %% Deployments
    class_hash = get_declarations()

    deployments = {}
    deployments["kakarot"] = await deploy(
        "kakarot",
        account.address,  # owner
        ETH_TOKEN_ADDRESS,  # native_token_address_
        class_hash["contract_account"],  # contract_account_class_hash_
        class_hash["externally_owned_account"],  # externally_owned_account_class_hash
        class_hash["proxy"],  # account_proxy_class_hash
        DEPLOY_FEE,
    )
    deployments["blockhash_registry"] = await deploy(
        "blockhash_registry",
        deployments["kakarot"]["address"],  # kakarot address
    )

    deployments["EVM"] = await deploy(
        "EVM",
        ETH_TOKEN_ADDRESS,  # native_token_address_
        class_hash["contract_account"],  # contract_account_class_hash_
        class_hash["proxy"],  # account_proxy_class_hash
        deployments["blockhash_registry"]["address"],  # blockhash_registry address
    )

    dump_deployments(deployments)

    logger.info("⏳ Configuring Contracts...")
    await invoke(
        "kakarot",
        "set_blockhash_registry",
        deployments["blockhash_registry"]["address"],
    )
    logger.info("✅ Configuration Complete")

    if EVM_ADDRESS:
        logger.info(f"ℹ️  Found default EVM address {EVM_ADDRESS} to deploy an EOA for")
        from scripts.utils.kakarot import deploy_and_fund_evm_address

        await deploy_and_fund_evm_address(EVM_ADDRESS, amount=1)


# %% Run
if __name__ == "__main__":
    run(main())
