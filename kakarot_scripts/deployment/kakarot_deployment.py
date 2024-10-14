# %% Imports
import logging

from uvloop import run

from kakarot_scripts.constants import (
    BLOCK_GAS_LIMIT,
    DEFAULT_GAS_PRICE,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    NETWORK,
    RPC_CLIENT,
    NetworkType,
)
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import (
    dump_deployments,
    execute_calls,
    get_declarations,
    get_deployments,
    get_starknet_account,
    invoke,
    register_lazy_account,
    remove_lazy_account,
)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %%
async def deploy_or_upgrade_kakarot(owner):
    # %% Load data
    class_hash = get_declarations()
    starknet_deployments = get_deployments()

    # Deploy or upgrade Kakarot
    if starknet_deployments.get("kakarot") and NETWORK["type"] is not NetworkType.DEV:
        logger.info("ℹ️  Kakarot already deployed, checking version.")
        deployed_class_hash = await RPC_CLIENT.get_class_hash_at(
            starknet_deployments["kakarot"]
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
            owner.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            BLOCK_GAS_LIMIT,
        )
        await invoke(
            "kakarot",
            "set_base_fee",
            DEFAULT_GAS_PRICE,
            address=starknet_deployments["kakarot"],
        )
        # Temporarily set the coinbase to the default EVM deployer so that
        # fees are not sent to 0x0 but rather sent back to the deployer itself,
        # until the coinbase is set to the deployed contract later on.
        await invoke(
            "kakarot",
            "set_coinbase",
            int(EVM_ADDRESS, 16),
            address=starknet_deployments["kakarot"],
        )

    dump_deployments(starknet_deployments)


# %% Run
async def main():
    try:
        await RPC_CLIENT.get_class_by_hash(get_declarations()["kakarot"])
    except Exception:
        logger.error("❌ Kakarot is not declared, exiting...")
        return

    account = await get_starknet_account()
    register_lazy_account(account.address)
    await deploy_or_upgrade_kakarot(account)
    await execute_calls()
    remove_lazy_account(account.address)


def main_sync():
    run(main())


if __name__ == "__main__":
    main_sync()
