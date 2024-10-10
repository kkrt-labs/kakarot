import logging

from uvloop import run

from kakarot_scripts.deployment.declarations import declare_contracts
from kakarot_scripts.deployment.evm_deployments import deploy_evm_contracts
from kakarot_scripts.deployment.kakarot_deployment import deploy_or_upgrade_kakarot
from kakarot_scripts.deployment.pre_eip155_deployments import (
    deploy_pre_eip155_contracts,
    whitelist_pre_eip155_contracts,
)
from kakarot_scripts.deployment.starknet_deployments import deploy_starknet_contracts
from kakarot_scripts.utils.starknet import (
    execute_calls,
    get_balance,
    get_starknet_account,
    register_lazy_account,
    remove_lazy_account,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


async def main():
    account = await get_starknet_account()
    register_lazy_account(account.address)
    logger.info(f"ℹ️  Using account 0x{account.address:064x} as deployer")
    balance_before = await get_balance(account.address)
    await declare_contracts()

    # Batched deployments of non-conflicting contracts
    await deploy_starknet_contracts(account)
    await deploy_or_upgrade_kakarot(account)
    await execute_calls()

    # Whitelists depend on a deployed kakarot
    await whitelist_pre_eip155_contracts()
    await execute_calls()
    remove_lazy_account(account.address)

    # Sequential deployments
    await deploy_pre_eip155_contracts()
    await deploy_evm_contracts(account)

    balance_after = await get_balance(account.address)
    logger.info(
        f"ℹ️  Deployer balance changed from {balance_before / 1e18} to {balance_after / 1e18} ETH"
    )


def main_sync():
    run(main())


if __name__ == "__main__":
    main_sync()
