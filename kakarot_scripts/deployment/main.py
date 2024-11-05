# %% Imports
import logging

from uvloop import run

from kakarot_scripts.constants import EVM_ADDRESS, L1_RPC_PROVIDER, NETWORK
from kakarot_scripts.deployment.declarations import declare_contracts
from kakarot_scripts.deployment.dualvm_token_deployments import deploy_dualvm_tokens
from kakarot_scripts.deployment.evm_deployments import deploy_evm_contracts
from kakarot_scripts.deployment.kakarot_deployment import deploy_or_upgrade_kakarot
from kakarot_scripts.deployment.messaging_deployments import (
    deploy_l1_messaging_contracts,
    deploy_l2_messaging_contracts,
)
from kakarot_scripts.deployment.pre_eip155_deployments import (
    deploy_pre_eip155_contracts,
    deploy_pre_eip155_senders,
    whitelist_pre_eip155_txs,
)
from kakarot_scripts.deployment.starknet_deployments import deploy_starknet_contracts
from kakarot_scripts.utils.kakarot import eth_balance_of, get_contract
from kakarot_scripts.utils.starknet import (
    call,
    execute_calls,
    get_balance,
    get_starknet_account,
    register_lazy_account,
    remove_lazy_account,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %%
async def main():

    # %% Account initialization
    account = await get_starknet_account()
    register_lazy_account(account.address)
    logger.info(f"ℹ️  Using account 0x{account.address:064x} as deployer")
    balance_before = await get_balance(account.address)

    # %% Declarations
    await declare_contracts()

    # %% Starknet Deployments
    await deploy_starknet_contracts(account)
    await deploy_or_upgrade_kakarot(account)
    await execute_calls()

    # %% EVM Deployments
    await deploy_pre_eip155_senders()
    await deploy_evm_contracts()
    await execute_calls()

    # DualVM Tokens deployment have their own invoke batching strategy
    await deploy_dualvm_tokens()

    await whitelist_pre_eip155_txs()
    await execute_calls()

    # Must be sequential
    remove_lazy_account(account.address)
    # Needs whitelist tx to be executed first
    await deploy_pre_eip155_contracts()

    # %% Messaging
    await deploy_l1_messaging_contracts()
    await deploy_l2_messaging_contracts()

    # %% Tear down
    coinbase_address = (await call("kakarot", "get_coinbase")).coinbase
    if coinbase_address == 0:
        logger.error("❌ Coinbase is set to 0, all transaction fees will be lost")
    else:
        logger.info(f"✅ Coinbase set to: 0x{coinbase_address:040x}")
        coinbase = await get_contract(
            "Kakarot", "Coinbase", address=f"0x{coinbase_address:040x}"
        )
        coinbase_balance = await eth_balance_of(coinbase_address)
        if coinbase_balance / 1e18 > 0.001:
            logger.info(
                f"ℹ️ Withdrawing {coinbase_balance / 1e18} ETH from Coinbase to Starknet deployer"
            )
            await coinbase.withdraw(account.address)

    balance_after = await get_balance(account.address)
    logger.info(
        f"💰  Deployer balance changed from {balance_before / 1e18} to {balance_after / 1e18} ETH"
    )
    logger.info(
        f"💰  Coinbase balance: {await eth_balance_of(coinbase_address) / 1e18} ETH"
    )
    logger.info(
        "💰  Relayers balance:\n"
        + "\n".join(
            [
                f"  {hex(account.address)}: {await get_balance(account.address) / 1e18} ETH"
                for account in NETWORK["relayers"].relayer_accounts
            ]
        )
    )
    l2_balance = await eth_balance_of(EVM_ADDRESS) / 1e18
    l1_balance = L1_RPC_PROVIDER.eth.get_balance(EVM_ADDRESS) / 1e18
    logger.info(
        f"💰  EVM deployer balance:\n    L2: {l2_balance} ETH\n    L1: {l1_balance} ETH"
    )


# %%


def main_sync():
    run(main())


# %%

if __name__ == "__main__":
    main_sync()
