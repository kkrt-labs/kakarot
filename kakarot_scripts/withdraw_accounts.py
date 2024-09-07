# %% Imports
import logging
from asyncio import run

from kakarot_scripts.constants import ETH_TOKEN_ADDRESS, NETWORK, RPC_CLIENT
from kakarot_scripts.utils.starknet import get_balance, get_declarations, invoke

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Withdraw all accounts

    # TODO: List of {evm_address, starknet_address} dict to be retrieved from parsing Kakarot contract events
    contracts = []

    balance_prev = await get_balance(NETWORK["account_address"])
    logger.info(f"ℹ️  Current deployer balance {balance_prev / 1e18} ETH")
    for contract in contracts:
        balance = await get_balance(contract["starknet_address"])
        if balance == 0:
            logger.info(
                f"ℹ️  No balance to withdraw from EVM contract {contract['evm_address']}"
            )
            continue

        logger.info(
            f"ℹ️  Withdrawing {balance / 1e18} ETH from EVM contract {contract['evm_address']}"
        )
        current_class = await RPC_CLIENT.get_class_hash_at(contract["starknet_address"])
        await invoke(
            "kakarot",
            "upgrade_account",
            int(contract["evm_address"], 16),
            get_declarations()["BalanceSender"],
        )
        await invoke(
            "BalanceSender",
            "send_balance",
            ETH_TOKEN_ADDRESS,
            int(NETWORK["account_address"], 16),
            address=int(contract["starknet_address"], 16),
        )
        await invoke(
            "kakarot",
            "upgrade_account",
            int(contract["evm_address"], 16),
            current_class,
        )
    balance = await get_balance(NETWORK["account_address"])
    logger.info(
        f"ℹ️  Current deployer balance {balance / 1e18} ETH: {(balance - balance_prev) / 1e18} ETH recovered"
    )


# %% Run
if __name__ == "__main__":
    run(main())
