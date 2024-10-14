# %% Imports
import logging

from uvloop import run

from kakarot_scripts.constants import (
    BLOCK_GAS_LIMIT,
    COINBASE,
    ETH_TOKEN_ADDRESS,
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


# %%
async def deploy_starknet_contracts(account):

    # %% Deployments
    class_hash = get_declarations()
    starknet_deployments = get_deployments()

    if NETWORK["type"] is not NetworkType.PROD:
        starknet_deployments["EVM"] = await deploy_starknet(
            "EVM",
            account.address,
            ETH_TOKEN_ADDRESS,
            class_hash["account_contract"],
            class_hash["uninitialized_account"],
            class_hash["Cairo1Helpers"],
            BLOCK_GAS_LIMIT,
        )
        await invoke(
            "EVM",
            "set_coinbase",
            COINBASE,
            address=starknet_deployments["EVM"],
        )
        starknet_deployments["Counter"] = await deploy_starknet("Counter")
        starknet_deployments["MockPragmaOracle"] = await deploy_starknet(
            "MockPragmaOracle"
        )
        starknet_deployments["MockPragmaSummaryStats"] = await deploy_starknet(
            "MockPragmaSummaryStats"
        )
        starknet_deployments["UniversalLibraryCaller"] = await deploy_starknet(
            "UniversalLibraryCaller"
        )
        starknet_deployments["BenchmarkCairoCalls"] = await deploy_starknet(
            "BenchmarkCairoCalls"
        )

    dump_deployments(starknet_deployments)
    # %%
    return starknet_deployments


# %% Run
def main_sync():
    run(main())


async def main():
    try:
        await RPC_CLIENT.get_class_by_hash(get_declarations()["kakarot"])
    except Exception:
        logger.error("❌ Classes were not declared, exiting...")
        return
    account = await get_starknet_account()
    register_lazy_account(account.address)
    await deploy_starknet_contracts(account)
    await execute_calls()
    remove_lazy_account(account.address)


if __name__ == "__main__":
    main_sync()
