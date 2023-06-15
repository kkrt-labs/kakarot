# %% Imports
import logging
from asyncio import run
from math import ceil, log

from scripts.constants import (
    CHAIN_ID,
    COMPILED_CONTRACTS,
    DEBUG_MODE,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    NETWORK,
    RPC_CLIENT,
)
from scripts.utils.starknet import (
    declare,
    deploy,
    deploy_starknet_account,
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
    logger.info(
        f"ℹ️  Connected to CHAIN_ID {CHAIN_ID.value.to_bytes(ceil(log(CHAIN_ID.value, 256)), 'big')} "
        f"with RPC {RPC_CLIENT.url}"
    )
    if NETWORK == "madara":
        await deploy_starknet_account()
    account = await get_starknet_account()
    logger.info(f"ℹ️  Using account {hex(account.address)} as deployer")

    class_hash = {
        contract["contract_name"]: await declare(contract["contract_name"])
        for contract in COMPILED_CONTRACTS
        if not contract["devnet_only"] or DEBUG_MODE
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
    )
    deployments["blockhash_registry"] = await deploy(
        "blockhash_registry",
        deployments["kakarot"]["address"],
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

        await deploy_and_fund_evm_address(EVM_ADDRESS, 0.1)


# %% Run
if __name__ == "__main__":
    run(main())
