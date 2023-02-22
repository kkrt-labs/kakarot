import os
import re
from enum import Enum
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.gateway_client import GatewayClient

load_dotenv()

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
EVM_ADDRESS = os.getenv("EVM_ADDRESS")
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
ADDRESSES = {
    "testnet": "https://alpha4.starknet.io",
    "mainnet": "https://alpha-mainnet.starknet.io",
    "devnet": "http://127.0.0.1:5050",
    "testnet2": "https://alpha4-2.starknet.io",
}
GATEWAY_CLIENT = GatewayClient(net=ADDRESSES[NETWORK])
STARKNET_NETWORK = "alpha-mainnet" if NETWORK == "mainnet" else "alpha-goerli"


class ChainId(Enum):
    mainnet = int.from_bytes(b"SN_MAIN", "big")
    testnet = int.from_bytes(b"SN_GOERLI", "big")
    testnet2 = int.from_bytes(b"SN_GOERLI", "big")
    devnet = int.from_bytes(b"SN_GOERLI", "big")


CHAIN_ID = getattr(ChainId, NETWORK)

DEPLOYMENTS_DIR = Path("deployments") / NETWORK
BUILD_DIR = Path("build")
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}
