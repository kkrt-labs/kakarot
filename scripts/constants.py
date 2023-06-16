import os
import re
from enum import Enum
from pathlib import Path

from dotenv import load_dotenv
from eth_keys import keys
from starknet_py.net.full_node_client import FullNodeClient

load_dotenv()

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
EVM_ADDRESS = (
    EVM_PRIVATE_KEY
    and keys.PrivateKey(
        bytes.fromhex(EVM_PRIVATE_KEY[2:])
    ).public_key.to_checksum_address()
)

NETWORK = os.getenv("STARKNET_NETWORK", "devnet")
NETWORK = (
    "testnet"
    if re.match(r".*(testnet|goerli)$", NETWORK, flags=re.I)
    else "testnet2"
    if re.match(r".*(testnet|goerli)-?2$", NETWORK, flags=re.I)
    else "mainnet"
    if re.match(r".*(mainnet).*", NETWORK, flags=re.I)
    else "sharingan"
    if re.match(r".*(sharingan).*", NETWORK, flags=re.I)
    else "katana"
    if re.match(r".*(katana).*", NETWORK, flags=re.I)
    else "madara"
    if re.match(r".*(madara).*", NETWORK, flags=re.I)
    else "devnet"
)
STARKSCAN_URLS = {
    "mainnet": "https://starkscan.co",
    "testnet": "https://testnet.starkscan.co",
    "testnet2": "https://testnet-2.starkscan.co",
    "devnet": "https://devnet.starkscan.co",
    "sharingan": "https://starknet-madara.netlify.app/#/explorer/query",
    "katana": "",
    "madara": "",
}
STARKSCAN_URL = STARKSCAN_URLS[NETWORK]

if not os.getenv("RPC_KEY") and NETWORK in ["mainnet", "testnet", "testnet2"]:
    raise ValueError(f"RPC_KEY env variable is required when targeting {NETWORK}")
RPC_URLS = {
    "mainnet": f"https://starknet-mainnet.infura.io/v3/{os.getenv('RPC_KEY')}",
    "testnet": f"https://starknet-goerli.infura.io/v3/{os.getenv('RPC_KEY')}",
    "testnet2": f"https://starknet-goerli2.infura.io/v3/{os.getenv('RPC_KEY')}",
    "devnet": "http://127.0.0.1:5050/rpc",
    "sharingan": os.getenv("SHARINGAN_RPC_URL"),
    "katana": "http://127.0.0.1:5050",
    "madara": "http://127.0.0.1:9944",
}
RPC_CLIENT = FullNodeClient(node_url=RPC_URLS[NETWORK])


class ChainId(Enum):
    mainnet = int.from_bytes(b"SN_MAIN", "big")
    testnet = int.from_bytes(b"SN_GOERLI", "big")
    testnet2 = int.from_bytes(b"SN_GOERLI2", "big")
    devnet = int.from_bytes(b"SN_GOERLI", "big")
    sharingan = int.from_bytes(b"SN_GOERLI", "big")
    katana = int.from_bytes(b"KATANA", "big")
    madara = int.from_bytes(b"SN_GOERLI", "big")


BUILD_DIR = Path("build")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}


ACCOUNT_ADDRESS = os.environ.get(
    f"{NETWORK.upper()}_ACCOUNT_ADDRESS"
) or os.environ.get("ACCOUNT_ADDRESS")
PRIVATE_KEY = os.environ.get(f"{NETWORK.upper()}_PRIVATE_KEY") or os.environ.get(
    "PRIVATE_KEY"
)

DEPLOYMENTS_DIR = Path("deployments") / NETWORK
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

# TODO: get CHAIN_ID from RPC endpoint when starknet-py doesn't expect an enum
CHAIN_ID = getattr(ChainId, NETWORK)
KAKAROT_CHAIN_ID = 1263227476  # KKRT (0x4b4b5254) in ASCII
COMPILED_CONTRACTS = [
    {"contract_name": "kakarot", "is_account_contract": False},
    {"contract_name": "blockhash_registry", "is_account_contract": False},
    {"contract_name": "contract_account", "is_account_contract": False},
    {"contract_name": "externally_owned_account", "is_account_contract": True},
    {"contract_name": "proxy", "is_account_contract": False},
]
