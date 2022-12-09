import sys
import asyncio
from starknet_py.net.account.account_client import (AccountClient)
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.contract import Contract
from starknet_py.net.models import StarknetChainId
from starkware.crypto.signature.signature import private_to_stark_key
from starknet_py.net.gateway_client import GatewayClient
from utils import deployContract
from pathlib import Path

#Configure Admin AccountClient
private_key = int(sys.argv[1])
account_address = int(sys.argv[2],16)
public_key = private_to_stark_key(private_key)
signer_key_pair = KeyPair(private_key,public_key)
client = AccountClient(address=account_address, client=GatewayClient(net="testnet"), key_pair=signer_key_pair, chain=StarknetChainId.TESTNET, supported_tx_version=1)
kakarot_abi = [
    {
        "inputs": [
            {"name": "registry_address_", "type": "felt"},
        ],
        "name": "set_account_registry",
        "outputs": [],
        "type": "function",
    }
]

async def deployKakarot():

    print("----------------------------------")
    print("--- Deploying Kakarot Protocol ---")
    print("----------------------------------")
    print(".")
    print(".")
    print(".")

    #################################
    #                               #
    #   DECLARE & DEPLOY CONTRACTS  #
    #                               #
    #################################
    

    # Declare EVM Contract
    print("⏳ Declaring EVM Contract Account... ")
    declare_transaction = await client.sign_declare_transaction(
        compiled_contract=Path("./build/", "contract_account.json").read_text("utf-8"), max_fee=int(1e16)
    )
    resp = await client.declare(transaction=declare_transaction)
    await client.wait_for_tx(resp.transaction_hash)
    evm_account_class_hash = resp.class_hash
    print("Contract Account Class Hash: ", hex(evm_account_class_hash))

    # Declare Kakarot
    print("⏳ Declaring Kakarot Contract...: ")
    declare_transaction = await client.sign_declare_transaction(
        compiled_contract=Path("./build/", "kakarot.json").read_text("utf-8"), max_fee=int(1e16)
    )
    resp = await client.declare(transaction=declare_transaction)
    await client.wait_for_tx(resp.transaction_hash)
    kakarot_class_hash = resp.class_hash
    print("Kakarot Class Hash: ", hex(kakarot_class_hash))

    # Deploy Kakarot Proxy
    print("Deploying Kakarot Proxy")
    compiled_contract = Path("./build/", "kakarot_proxy.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[
        kakarot_class_hash,        
        1679326747767113184781509514654930448714911516044653930322593061206440237873, # init selector
        [
            account_address, # Owner Address (of implementation and proxy)
            2087021424722619777119509474943472645767659996348769578120564519014510906823, # ETH ERC20 on testnet 1 & 2
            evm_account_class_hash
        ]
    ])
    kakarotProxy = Contract(address=contract_address, abi=kakarot_abi, client=client)
    print("Kakarot Proxy Address: ",contract_address)

    # Deploy Registry
    print("Deploying Account Registry")
    compiled_contract = Path("./build/", "account_registry.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address])
    registryContract = await Contract.from_address(address=int(contract_address,16),client=client)
    print("Account Registry Address: ",contract_address)

    ##########################
    #                        #
    #   CONFIGURE CONTRACTS  #
    #                        #
    ##########################   

    print("...Configuring Conctracts...")
    # Set Account Registry Owner
    invocation = await registryContract.functions["transfer_ownership"].invoke(kakarotProxy.address,max_fee=50000000000000000000)
    print("Transfering Account Registry Ownership...")
    await invocation.wait_for_acceptance()

    # Set Account Registry in Kakarot 
    invocation = await kakarotProxy.functions["set_account_registry"].invoke(registryContract.address,max_fee=50000000000000000000)
    print("Set account registry in Kakarot...")
    await invocation.wait_for_acceptance()

asyncio.run(deployKakarot())

