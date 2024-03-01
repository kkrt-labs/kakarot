# %% Imports
import logging
from asyncio import run

from scripts.constants import (
    DECLARED_CONTRACTS,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    NETWORK,
    RPC_CLIENT,
)
from scripts.utils.starknet import (
    declare,
    deploy,
    dump_declarations,
    dump_deployments,
    get_declarations,
    get_deployments,
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
        contract["contract_name"]: await declare(contract)
        for contract in DECLARED_CONTRACTS
    }
    dump_declarations(class_hash)

    # %% Deployments
    class_hash = get_declarations()

    deployments = get_deployments()
    if deployments.get("kakarot"):
        logger.info("ℹ️  Kakarot already deployed, checking version.")
        deployed_class_hash = await RPC_CLIENT.get_class_hash_at(
            deployments["kakarot"]["address"]
        )
        if deployed_class_hash != class_hash["kakarot"]:
            await invoke("kakarot", "upgrade", class_hash["kakarot"])
        else:
            logger.info("✅ Kakarot already up to date.")
    else:
        deployments["kakarot"] = await deploy(
            "kakarot",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["contract_account"],  # contract_account_class_hash_
            class_hash[
                "externally_owned_account"
            ],  # externally_owned_account_class_hash
            class_hash["proxy"],  # account_proxy_class_hash
            class_hash["Precompiles"],
        )

    if NETWORK["devnet"]:
        deployments["EVM"] = await deploy(
            "EVM",
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["contract_account"],  # contract_account_class_hash_
            class_hash["proxy"],  # account_proxy_class_hash
            class_hash["Precompiles"],
        )

        if EVM_ADDRESS:
            logger.info(f"ℹ️  Found default EVM address {EVM_ADDRESS}")
            from scripts.utils.kakarot import get_eoa

            await get_eoa(amount=100)

    dump_deployments(deployments)


# %% Run
if __name__ == "__main__":
    run(main())
