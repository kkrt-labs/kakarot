# %% Imports
import logging
import os
from asyncio import run

import requests

from kakarot_scripts.constants import ETH_TOKEN_ADDRESS, NETWORK, RPC_CLIENT
from kakarot_scripts.utils.starknet import get_balance, get_declarations, invoke

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Fetch contract events
def get_contracts():
    url = f"https://sepolia-api.voyager.online/beta/events?ps=10&p=1&contract={os.getenv('KAKAROT_SEPOLIA_ACCOUNT_ADDRESS')}"
    headers = {
        "accept": "application/json",
        "x-api-key": os.getenv("VOYAGER_API_KEY"),
    }
    response = requests.get(url, headers=headers)
    return [
        {
            "evm_address": "0x" + raw[2:22].hex(),
            "starknet_address": "0x" + raw[23:].hex(),
        }
        for raw in (
            bytes(contract["data"]["data"]) for contract in response.json()["items"]
        )
    ]


# %% Main
async def main():
    # %% Withdraw all accounts

    contracts = get_contracts()

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
