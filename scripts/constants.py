import os
import re
from enum import Enum
from pathlib import Path

from dotenv import load_dotenv
from eth_keys import keys
from starknet_py.net.gateway_client import GatewayClient

load_dotenv()

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
EVM_ADDRESS = (
    EVM_PRIVATE_KEY
    and keys.PrivateKey(
        bytes.fromhex(EVM_PRIVATE_KEY[2:])
    ).public_key.to_checksum_address()
)
NETWORK = os.getenv("STARKNET_NETWORK", "starknet-devnet")
NETWORK = (
    "testnet"
    if re.match(r".*(testnet|goerli)$", NETWORK, flags=re.I)
    else "testnet2"
    if re.match(r".*(testnet|goerli)-?2$", NETWORK, flags=re.I)
    else "devnet"
    if re.match(r".*(devnet|local).*", NETWORK, flags=re.I)
    else "mainnet"
)
GATEWAY_URLS = {
    "mainnet": "https://alpha-mainnet.starknet.io",
    "testnet": "https://alpha4.starknet.io",
    "testnet2": "https://alpha4-2.starknet.io",
    "devnet": "http://127.0.0.1:5050",
}
GATEWAY_CLIENT = GatewayClient(net=GATEWAY_URLS[NETWORK])
STARKNET_NETWORKS = {
    "mainnet": "alpha-mainnet",
    "testnet": "alpha-goerli",
    "testnet2": "alpha-goerli2",
    "devnet": "alpha-goerli",
}
STARKNET_NETWORK = STARKNET_NETWORKS[NETWORK]
STARKSCAN_URLS = {
    "mainnet": "https://starkscan.co",
    "testnet": "https://testnet.starkscan.co",
    "testnet2": "https://testnet-2.starkscan.co",
    "devnet": "https://devnet.starkscan.co",
}
STARKSCAN_URL = STARKSCAN_URLS[NETWORK]


class ChainId(Enum):
    mainnet = int.from_bytes(b"SN_MAIN", "big")
    testnet = int.from_bytes(b"SN_GOERLI", "big")
    testnet2 = int.from_bytes(b"SN_GOERLI2", "big")
    devnet = int.from_bytes(b"SN_GOERLI", "big")


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

CHAIN_ID = getattr(ChainId, NETWORK)
KAKAROT_CHAIN_ID = 1263227476  # KKRT (0x4b4b5254) in ASCII
