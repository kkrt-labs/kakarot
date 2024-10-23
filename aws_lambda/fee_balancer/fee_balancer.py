import asyncio
import json
import logging
import os

import boto3
from web3 import Web3

from kakarot_scripts.utils.starknet import (
    get_balance,
    get_contract,
    get_eth_contract,
    get_starknet_account,
    wait_for_transaction,
)

logger = logging.getLogger()
logger.setLevel("INFO")

client = boto3.client("secretsmanager")
ssm = boto3.client("ssm")
node_url = os.getenv("NODE_URL")
web3 = Web3(Web3.HTTPProvider(node_url))

with open("coinbase_abi.json", "r") as f:
    coinbase_abi = json.load(f)

contract_address = os.getenv("COINBASE_CONTRACT_ADDRESS")

# Create smart contract instance
contract = web3.eth.contract(address=contract_address, abi=coinbase_abi)


def lambda_handler(event, context):
    return asyncio.get_event_loop().run_until_complete(check_and_fund_relayers())


async def check_and_fund_relayers():
    # Load relayers information from JSON file
    with open("relayers.json", "r") as f:
        relayers = json.load(f)

    # Retrieve starknet secret from AWS Secrets Manager
    response = client.get_secret_value(SecretId="relayers_fund_account")
    secret_dict = json.loads(response["SecretString"])

    starknet_address, starknet_private_key = next(iter(secret_dict.items()))
    starknet_account = await get_starknet_account(
        starknet_address, starknet_private_key
    )
    eth_contract = await get_eth_contract(starknet_account)

    # Retrieve eth secret from AWS Secrets Manager
    response = client.get_secret_value(SecretId="eth_coinbase_owner")
    secret_dict = json.loads(response["SecretString"])

    eth_address, eth_private_key = next(iter(secret_dict.items()))
    nonce = web3.eth.get_transaction_count(eth_address)

    account_balance_before_withdraw = await get_balance(
        starknet_account.starknet_address, eth_contract
    )

    # withdraw fees from coinbase contract
    await withdraw_fee(starknet_address, nonce, eth_address, eth_private_key)

    account_balance = await get_balance(starknet_account.starknet_address, eth_contract)
    relayers_total_balance = await get_total_balance_of_relayers(relayers, eth_contract)

    actual_fee = account_balance - account_balance_before_withdraw

    # get the prev balances
    relayers_prev_total_balance = int(os.getenv("PREV_TOTAL_BALANCE"))

    # get the earning percentage
    earning_percentage = int(os.getenv("EARNING_PERCENTAGE"))

    cairo_counter = get_contract("Kakarot")

    yield cairo_counter

    base_fee = await cairo_counter.functions["get_base_fee"].call()
    logger.info(f"Base fee: {base_fee}")
    changed_fee = base_fee

    # check if the relayers balance is less than the prev balance
    if relayers_prev_total_balance + actual_fee < relayers_total_balance:
        # increase the base fee of 12.5%
        changed_fee += base_fee * 0.125
    # check if the relayers balance is more than the prev balance + the acceptable earning percentage
    elif relayers_prev_total_balance + actual_fee > relayers_total_balance + (
        earning_percentage * actual_fee / 100
    ):
        # decrease the base fee of 12.5%
        changed_fee -= base_fee * 0.125
    else:
        logger.info("No changes to the base fee")

    if changed_fee != base_fee:
        tx = await cairo_counter.functions["set_base_fee"].invoke_v1(base_fee)
        await wait_for_transaction(tx.hash)

    return {
        "statusCode": 200,
    }


async def get_total_balance_of_relayers(relayers, eth_contract, block_number):
    total_balance = 0

    for relayer in relayers:
        account_balance = await get_balance(
            relayer["address"], eth_contract, block_number
        )
        total_balance += account_balance

    return total_balance


async def withdraw_fee(starknet_address, nonce, eth_address, eth_private_key):
    Chain_id = web3.eth.chain_id

    # Call your function
    call_function = contract.functions.withdraw(
        toStarknetAddress=starknet_address
    ).build_transaction({"chainId": Chain_id, "from": eth_address, "nonce": nonce})

    # Sign transaction
    signed_tx = web3.eth.account.sign_transaction(
        call_function, private_key=eth_private_key
    )

    # Send transaction
    send_tx = web3.eth.send_raw_transaction(signed_tx.raw_transaction)

    # Wait for transaction receipt
    tx_receipt = web3.eth.wait_for_transaction_receipt(send_tx)
    logger.info(tx_receipt)


if __name__ == "__main__":
    asyncio.run(check_and_fund_relayers())
