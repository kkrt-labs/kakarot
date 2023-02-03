import json
import logging
import os
from asyncio import run
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.account.account_client import AccountClient
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starkware.crypto.signature.signature import private_to_stark_key

from scripts.utils import declare_and_deploy_contracts, declare_contract

# Logging conf, just want to print results to console
logging.basicConfig(level=logging.INFO)

# Loading .env file
load_dotenv()

# Address of the ETH token on mainnet,testnet1 and testnet2
ETH_ADDRESS = (
    2087021424722619777119509474943472645767659996348769578120564519014510906823
)
# Set a high max fee for the deployments
MAX_FEE = int(1e16)
BUILD_PATH = Path("build")


# Get env variables
if os.environ.get("PRIVATE_KEY") is None:
    raise ValueError("Deploy script requires PRIVATE_KEY to be set in .env file")
if os.environ.get("ACCOUNT_ADDRESS") is None:
    raise ValueError("Deploy script requires ACCOUNT_ADDRESS to be set in .env file")

private_key = int(os.environ["PRIVATE_KEY"])
account_address = int(os.environ["ACCOUNT_ADDRESS"], 16)
network = os.getenv("NETWORK", "testnet")

# Current starknet.py version does not support testnet2 as a default network
if network == "testnet2":
    network = "https://alpha4-2.starknet.io"

# Configure Admin AccountClient
public_key = private_to_stark_key(private_key)
signer_key_pair = KeyPair(private_key, public_key)
client = AccountClient(
    address=account_address,
    client=GatewayClient(net=network),
    key_pair=signer_key_pair,
    chain=StarknetChainId.TESTNET,
    supported_tx_version=1,
)


async def main():

    logging.info("⏳ Declaring accounts...")

    contract_account_class_hash = await declare_contract(client, "contract_account")
    externally_owned_account_class_hash = await declare_contract(
        client, "externally_owned_account"
    )
    account_proxy_class_hash = await declare_contract(client, "proxy_account")

    logging.info("✅ Accounts declared")

    logging.info("⏳ Deploying contracts...")

    (kakarot_contract,) = await declare_and_deploy_contracts(
        client=client,
        contracts=["kakarot"],
        calldata=[
            [
                account_address,  # owner
                ETH_ADDRESS,  # native_token_address_
                contract_account_class_hash,  # contract_account_class_hash_
                externally_owned_account_class_hash,  # externally_owned_account_class_hash
                account_proxy_class_hash,  # account_proxy_class_hash
            ]
        ],
    )
    (blockhash_registry,) = await declare_and_deploy_contracts(
        client=client,
        contracts=["blockhash_registry"],
        calldata=[[kakarot_contract.address]],
    )

    logging.info("✅ Contracts deployed")

    # Log deployed addresses
    with open("deployed_addresses.json", "w") as file:
        json.dump(
            {
                "addresses": {
                    "kakarot": f"0x{kakarot_contract.address:x}",
                    "blockhash_registry": f"0x{blockhash_registry.address:x}",
                },
                "class_hashes": {
                    "contract_account": f"0x{contract_account_class_hash:x}",
                    "externally_owned_account": f"0x{externally_owned_account_class_hash:x}",
                    "account_proxy": f"0x{account_proxy_class_hash:x}",
                },
            },
            file,
            indent=2,
        )
        file.write("\n")

    logging.info("⏳ Configuring Contracts...")

    # Set Blockhash Registry in Kakarot
    invocation = await kakarot_contract.functions["set_blockhash_registry"].invoke(
        blockhash_registry.address, max_fee=MAX_FEE
    )
    await invocation.wait_for_acceptance()

    logging.info("✅ Configuration Complete")


if __name__ == "__main__":
    run(main())
