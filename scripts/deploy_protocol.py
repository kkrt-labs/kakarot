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
from utils import declare_and_deploy_contract, declare_contract
from pathlib import Path
from dotenv import load_dotenv

#Logging conf, just want to print results to console
logging.basicConfig(level = logging.INFO)

# Address of the ETH token on mainnet,testnet1 and testnet2
ETH_ADDRESS = 2087021424722619777119509474943472645767659996348769578120564519014510906823
# Set a high max fee for the deployments
MAX_FEE = int(1e16)
BUILD_PATH = Path("build")

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
    logging.info(".")
    logging.info(".")
    logging.info(".")

    #################################
    #                               #
    #   DECLARE & DEPLOY CONTRACTS  #
    #                               #
    #################################
    

    # Declare EVM Contract
    logging.info("⏳ Declaring EVM Contract Account... ")
    evm_account_class_hash = await declare_contract(client,Path(BUILD_PATH, "contract_account.json").read_text("utf-8"))
    logging.info("Contract Account Class Hash: %s", hex(evm_account_class_hash))

    # Declare Kakarot
    logging.info("⏳ Declaring Kakarot Contract...: ")
    kakarot_class_hash = await declare_contract(client,Path(BUILD_PATH, "kakarot.json").read_text("utf-8"))
    logging.info("Kakarot Class Hash: %s", hex(kakarot_class_hash))

    # Deploy Kakarot Proxy
    logging.info("Deploying Kakarot Proxy")
    compiled_contract = Path(BUILD_PATH, "kakarot_proxy.json").read_text("utf-8")
    contract_address = await declare_and_deploy_contract(client=client,compiled_contract=compiled_contract,calldata=[
        kakarot_class_hash,        
        1679326747767113184781509514654930448714911516044653930322593061206440237873, # init selector
        [
            account_address, # Owner Address (of implementation and proxy)
            ETH_ADDRESS, # ETH ERC20 on testnet 1 & 2
            evm_account_class_hash
        ]
    ])
    kakarot_proxy = Contract(address=contract_address, abi=kakarot_abi, client=client)
    logging.info("Kakarot Proxy Address: %s",contract_address)

    # Deploy Registry
    logging.info("Deploying Account Registry")
    compiled_contract = Path(BUILD_PATH, "account_registry.json").read_text("utf-8")
    contract_address = await declare_and_deploy_contract(client=client,compiled_contract=compiled_contract,calldata=[kakarot_proxy.address])
    registry_contract = await Contract.from_address(address=int(contract_address,16),client=client)
    logging.info("Account Registry Address: %s",contract_address)

    ##########################
    #                        #
    #   CONFIGURE CONTRACTS  #
    #                        #
    ##########################   

    # Set Account Registry in Kakarot 
    invocation = await kakarot_proxy.functions["set_account_registry"].invoke(registry_contract.address,max_fee=MAX_FEE)
    logging.info("Set account registry in Kakarot...")
    await invocation.wait_for_acceptance()

if __name__ == "__main__":
    run(main())

