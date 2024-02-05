# %% Imports
import logging
import os
from asyncio import run

from scripts.constants import (
    DECLARED_CONTRACTS,
    DEPLOYER_ACCOUNT_PRIVATE_KEY,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    NETWORK,
)
from scripts.utils.starknet import (
    declare,
    deploy,
    deploy_starknet_account,
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_starknet_account,
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
        contract["contract_name"]: await declare(contract)
        for contract in DECLARED_CONTRACTS
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
        class_hash["Precompiles"],
    )

    if NETWORK["name"] in ["madara", "katana", os.getenv("RPC_NAME", "custom-rpc")]:
        deployments["EVM"] = await deploy(
            "EVM",
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["contract_account"],  # contract_account_class_hash_
            class_hash["proxy"],  # account_proxy_class_hash
            class_hash["Precompiles"],
        )
        deployments["deployer_account"] = await deploy_starknet_account(
            class_hash["OpenzeppelinAccount"], private_key=DEPLOYER_ACCOUNT_PRIVATE_KEY
        )

    dump_deployments(deployments)

    if EVM_ADDRESS:
        logger.info(f"ℹ️  Found default EVM address {EVM_ADDRESS}")
        from scripts.utils.kakarot import get_eoa

        await get_eoa(amount=100)


# %% Run
if __name__ == "__main__":
    run(main())
