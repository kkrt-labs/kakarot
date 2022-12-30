import os
import logging
import json
from asyncio import run
from starknet_py.net.account.account_client import (AccountClient)
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.contract import Contract
from starknet_py.net.models import StarknetChainId
from starkware.crypto.signature.signature import private_to_stark_key
from starknet_py.net.gateway_client import GatewayClient
from utils import declare_and_deploy_contract, declare_contract, create_log_file
from pathlib import Path
from dotenv import load_dotenv

#Logging conf, just want to print results to console
logging.basicConfig(level = logging.INFO)

# Address of the ETH token on mainnet,testnet1 and testnet2
ETH_ADDRESS = 2087021424722619777119509474943472645767659996348769578120564519014510906823
# Set a high max fee for the deployments
MAX_FEE = int(1e16)
BUILD_PATH = Path("build")

# Load compiled contracts
ACCOUNT_REGISTRY_COMPILED = Path(BUILD_PATH, "account_registry.json").read_text("utf-8")
BLOCKHASH_REGISTRY_COMPILED = Path(BUILD_PATH, "blockhash_registry.json").read_text("utf-8")
KAKAROT_COMPILED = Path(BUILD_PATH, "kakarot.json").read_text("utf-8")

# Loading .env file
load_dotenv()

# Get env variables
private_key = int(os.environ.get("PRIVATE_KEY"))
account_address = int(os.environ.get("ACCOUNT_ADDRESS"), 16)
network = os.getenv('NETWORK')

#Current starknet.py version does not support testnet2 as a default network
if network == "testnet2":
    network = "https://alpha4-2.starknet.io"

#Configure Admin AccountClient
public_key = private_to_stark_key(private_key)
signer_key_pair = KeyPair(private_key,public_key)
client = AccountClient(address=account_address, client=GatewayClient(net=network), key_pair=signer_key_pair, chain=StarknetChainId.TESTNET, supported_tx_version=1)
#Get Kakarot ABI
with open(Path(BUILD_PATH, 'kakarot_abi.json')) as abi_file:
    kakarot_abi = json.load(abi_file)

async def main():

    logging.info("----------------------------------")
    logging.info("--- Deploying Kakarot Protocol ---")
    logging.info("----------------------------------")
    logging.info("-------Patience is a Virtue-------")

    # Create Log file which holds newly deployed addresses
    await create_log_file()

    #################################
    #                               #
    #   DECLARE & DEPLOY CONTRACTS  #
    #                               #
    #################################
    
    # Declare EVM Contract
    evm_account_class_hash = await declare_contract(client,Path(BUILD_PATH, "contract_account.json").read_text("utf-8"))
    logging.info("✅ Contract Account Class Hash: %s", hex(evm_account_class_hash))

    # Deploy Kakarot
    contract_addresses = await declare_and_deploy_contract(client=client,compiled_contracts=[KAKAROT_COMPILED],calldata=[
        [
            account_address, # Owner Address (of implementation and proxy)
            ETH_ADDRESS, # ETH ERC20 on testnet 1 & 2
            evm_account_class_hash
        ]
    ])
    kakarot_contract = Contract(address=contract_addresses[0], abi=kakarot_abi, client=client)

    # Log deployed addresses
    with open('deployed_addresses.json', 'r') as file:
        data = json.load(file)
    data['addresses']['kakarot'] = hex(kakarot_contract.address)
    data['addresses']['kakarot_class_hash'] = hex(evm_account_class_hash)
    with open('deployed_addresses.json', 'w') as file:
        json.dump(data, file)
    logging.info("✅ Kakarot Address: %s", hex(kakarot_contract.address))

    # Deploy Account and Blockhash Registry
    contract_addresses = await declare_and_deploy_contract(client=client,compiled_contracts=[ACCOUNT_REGISTRY_COMPILED,BLOCKHASH_REGISTRY_COMPILED],calldata=[
        [kakarot_contract.address],
        [kakarot_contract.address]
    ])
    account_registry_address = contract_addresses[0]
    blockhash_registry_address = contract_addresses[1]

    # Log deployed addresses
    with open('deployed_addresses.json', 'r') as file:
        data = json.load(file)
    data['addresses']['account_registry'] = hex(account_registry_address)
    data['addresses']['blockhash_registry'] = hex(blockhash_registry_address)
    with open('deployed_addresses.json', 'w') as file:
        json.dump(data, file)
    logging.info("✅ Account Registry Address: %s", hex(account_registry_address))
    logging.info("✅ Blockhash Registry Address: %s", hex(blockhash_registry_address))

    ##########################
    #                        #
    #   CONFIGURE CONTRACTS  #
    #                        #
    ##########################   

    logging.info("⏳ Configuring Contracts...")

    # Set Account Registry in Kakarot 
    invocation = await kakarot_contract.functions["set_account_registry"].invoke(account_registry_address,max_fee=MAX_FEE)
    await invocation.wait_for_acceptance()

    # Set Blockhash Registry in Kakarot 
    invocation = await kakarot_contract.functions["set_blockhash_registry"].invoke(blockhash_registry_address,max_fee=MAX_FEE)
    await invocation.wait_for_acceptance()

    logging.info("✅ Configuration Complete")

if __name__ == "__main__":
    run(main())

