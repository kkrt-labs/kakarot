# %% Imports
import logging
from asyncio import run

from kakarot_scripts.constants import (
    BLOCK_GAS_LIMIT,
    COINBASE,
    DECLARED_CONTRACTS,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    NETWORK,
    RPC_CLIENT,
)
from kakarot_scripts.utils.starknet import (
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
    if deployments.get("kakarot") and not NETWORK["devnet"]:
        logger.info("ℹ️  Kakarot already deployed, checking version.")
        deployed_class_hash = await RPC_CLIENT.get_class_hash_at(
            deployments["kakarot"]["address"]
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
        deployments["kakarot"] = await deploy(
            "kakarot",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            COINBASE,
            BLOCK_GAS_LIMIT,
        )

    if deployments.get("EVM") and NETWORK["staging"]:
        logger.info("ℹ️  EVM already deployed, checking version.")
        deployed_class_hash = await RPC_CLIENT.get_class_hash_at(
            deployments["EVM"]["address"]
        )
        if deployed_class_hash != class_hash["EVM"]:
            deployments["EVM"] = await deploy(
                "EVM",
                account.address,  # owner
                ETH_TOKEN_ADDRESS,  # native_token_address_
                class_hash["account_contract"],  # account_contract_class_hash_
                class_hash[
                    "uninitialized_account"
                ],  # uninitialized_account_class_hash_
                class_hash["Cairo1Helpers"],
                COINBASE,
                BLOCK_GAS_LIMIT,
            )

    if NETWORK["devnet"]:
        deployments["EVM"] = await deploy(
            "EVM",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            COINBASE,
            BLOCK_GAS_LIMIT,
        )
        deployments["Counter"] = await deploy("Counter")
        deployments["MockPragmaOracle"] = await deploy("MockPragmaOracle")

    dump_deployments(deployments)

    if EVM_ADDRESS:
        logger.info(f"ℹ️  Found default EVM address {EVM_ADDRESS}")
        from kakarot_scripts.utils.kakarot import get_eoa

        amount = 0.02 if not NETWORK["devnet"] else 100
        await get_eoa(amount=amount)


# %% Run
if __name__ == "__main__":
    run(main())
