import asyncio
import json
import os

import boto3
import urllib3
from constants import NETWORK
from starknet import fund_address, get_balance, get_eth_contract

http = urllib3.PoolManager()
client = boto3.client("secretsmanager")


def lambda_handler(event, context):
    return asyncio.get_event_loop().run_until_complete(check_and_fund_relayers())


async def check_and_fund_relayers():
    funding_account_lower_limit = 10
    relayers_lower_limit = 0.05
    amount_to_fund = 0.1

    with open("relayers.json", "r") as f:
        relayers = json.load(f)
    response = client.get_secret_value(SecretId="relayers_fund_account")
    secret_json = json.loads(response["SecretString"])

    address, private_key = next(iter(secret_json.items()))
    NETWORK["account_address"] = address
    NETWORK["private_key"] = private_key
    relayer_account = next(NETWORK["relayers"])

    eth_contract = await get_eth_contract(relayer_account)
    balance = await get_balance(relayer_account.address, eth_contract)

    if balance / 1e18 < funding_account_lower_limit:
        message = f"Fund the relayer account {relayer_account.address}. Current balance: {balance / 1e18} ETH"
        send_message_to_slack(message)

    for relayer in relayers:
        address = hex(relayer["address"])
        relayer_balance = await get_balance(address, eth_contract)
        if relayer_balance / 1e18 < relayers_lower_limit:
            try:
                await fund_address(address, amount_to_fund, relayer_account)
                message = f"Funded address {address} with {amount_to_fund} ETH from {relayer_account.address}"
            except Exception:
                message = f"Failed to fund address {address}"
                send_message_to_slack(message)
                return {
                    "statusCode": 500,
                    "body": json.dumps({"Failed to fund address"}),
                }
        else:
            print(f"Address {address} has enough balance: {relayer_balance / 1e18} ETH")

    return {
        "statusCode": 200,
    }


def send_message_to_slack(message):
    url = os.environ.get("SLACK_WEBHOOK_URL")
    msg = {
        "channel": "",
        "username": "WEBHOOK_USERNAME",
        "text": message,
    }
    encoded_msg = json.dumps(msg).encode("utf-8")
    resp = http.request("POST", url, body=encoded_msg)
    print({"message": "test", "status_code": resp.status, "response": resp.data})
