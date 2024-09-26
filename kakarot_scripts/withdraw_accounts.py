# %% Imports
import logging
import os
from asyncio import run

import requests

from kakarot_scripts.constants import ETH_TOKEN_ADDRESS, NETWORK, RPC_CLIENT
from kakarot_scripts.utils.starknet import (
    get_balance,
    get_declarations,
    get_deployments,
    invoke,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Fetch contract events
def get_contracts():
    contract_address = hex(get_deployments()["kakarot"]["address"])
    logger.info(f"ℹ️  Fetching contracts from {contract_address}")
    url = f"{NETWORK['voyager_api_url']}/events?ps=10&p=1&contract={contract_address}"
    headers = {
        "accept": "application/json",
        "x-api-key": os.getenv("VOYAGER_API_KEY"),
    }
    response = requests.get(url, headers=headers)
    return [
        {item["name"]: item["value"] for item in event["dataDecoded"]}
        for event in response.json()["items"]
        if event.get("name") == "evm_contract_deployed"
    ]


# %% Main
async def main():
    # %% Withdraw all accounts

    contracts = get_contracts()

    balance_prev = await get_balance(NETWORK["account_address"])
    logger.info(f"ℹ️  Current deployer balance {balance_prev / 1e18} ETH")
    for contract in contracts:
        balance = await get_balance(contract["starknet_contract_address"])
        if balance == 0:
            logger.info(
                f"ℹ️  No balance to withdraw from EVM contract {contract['evm_contract_address']}"
            )
            continue

        logger.info(
            f"ℹ️  Withdrawing {balance / 1e18} ETH from EVM contract {contract['evm_contract_address']}"
        )
        current_class = await RPC_CLIENT.get_class_hash_at(
            contract["starknet_contract_address"]
        )
        await invoke(
            "kakarot",
            "upgrade_account",
            int(contract["evm_contract_address"], 16),
            get_declarations()["BalanceSender"],
        )
        await invoke(
            "BalanceSender",
            "send_balance",
            ETH_TOKEN_ADDRESS,
            int(NETWORK["account_address"], 16),
            address=int(contract["starknet_contract_address"], 16),
        )
        await invoke(
            "kakarot",
            "upgrade_account",
            int(contract["evm_contract_address"], 16),
            current_class,
        )
    balance = await get_balance(NETWORK["account_address"])
    logger.info(
        f"ℹ️  Current deployer balance {balance / 1e18} ETH: {(balance - balance_prev) / 1e18} ETH recovered"
    )


# %% Run
if __name__ == "__main__":
    run(main())
