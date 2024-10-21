import asyncio
import json
import logging

import boto3
import requests

from kakarot_scripts.constants import SLACK_WEBHOOK_URL
from kakarot_scripts.utils.starknet import (
    fund_address,
    get_balance,
    get_eth_contract,
    get_starknet_account,
)

client = boto3.client("secretsmanager")
logger = logging.getLogger()
logger.setLevel("INFO")


def lambda_handler(event, context):
    return asyncio.get_event_loop().run_until_complete(check_and_fund_relayers())


async def check_and_fund_relayers():
    """
    Check the balance of relayer accounts and fund them if necessary.

    This function performs the following steps:
    1. Loads relayer information from a JSON file.
    2. Retrieves the funding account details from AWS Secrets Manager.
    3. Checks the balance of the main relayer account.
    4. Iterates through all relayers, checking their balances and funding if needed.
    """
    # Constants for balance thresholds and funding amount
    funding_account_lower_limit = 10  # ETH
    relayers_lower_limit = 0.05  # ETH
    amount_to_fund = 0.1  # ETH

    # Load relayers information from JSON file
    with open("relayers.json", "r") as f:
        relayers = json.load(f)

    # Retrieve secret from AWS Secrets Manager
    response = client.get_secret_value(SecretId="relayers_fund_account")
    secret_dict = json.loads(response["SecretString"])

    address, private_key = next(iter(secret_dict.items()))
    account = await get_starknet_account(address, private_key)

    # Get ETH contract and check main relayer account balance
    eth_contract = await get_eth_contract(account)
    balance = await get_balance(account.address, eth_contract)

    # Alert if main relayer account balance is lower than the funding_account_lower_limit
    if balance / 1e18 < funding_account_lower_limit:
        message = f"Fund the relayer account 0x{account.address:064x}. Current balance: {balance / 1e18} ETH"
        send_message_to_slack(message)

    # Check and fund individual relayer accounts
    for relayer in relayers:
        relayer_balance = await get_balance(relayer["address"])
        if relayer_balance / 1e18 < relayers_lower_limit:
            try:
                await fund_address(address, amount_to_fund, account)
                message = f"Funded address {address} with {amount_to_fund} ETH from {account.address}"
            except Exception:
                message = f"Failed to fund address {address}"
                send_message_to_slack(message)
                return {
                    "statusCode": 500,
                    "body": json.dumps({"Failed to fund address"}),
                }
        else:
            logger.info(
                f"Address {address} has enough balance: {relayer_balance / 1e18} ETH"
            )

    return {
        "statusCode": 200,
    }


def send_message_to_slack(message):
    msg = {
        "channel": "",
        "username": "WEBHOOK_USERNAME",
        "text": message,
    }
    resp = requests.post(SLACK_WEBHOOK_URL, json=msg)
    logger.info(
        {"message": "test", "status_code": resp.status_code, "response": resp.text}
    )
