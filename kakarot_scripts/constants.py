import json
import logging
import os
from enum import Enum, IntEnum
from math import ceil, log
from pathlib import Path

import requests
from dotenv import load_dotenv
from eth_keys import keys
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv()

# Hardcode block gas limit to 20M
BLOCK_GAS_LIMIT = 20_000_000

BEACON_ROOT_ADDRESS = "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02"

NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "explorer_url": "https://starkscan.co",
        "rpc_url": f"https://starknet-mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "devnet": False,
        "chain_id": StarknetChainId.MAINNET,
    },
    "testnet": {
        "name": "testnet",
        "explorer_url": "https://testnet.starkscan.co",
        "rpc_url": f"https://starknet-goerli.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "devnet": False,
        "chain_id": StarknetChainId.GOERLI,
    },
    "starknet-devnet": {
        "name": "starknet-devnet",
        "explorer_url": "",
        "rpc_url": "http://127.0.0.1:5050/rpc",
        "devnet": True,
        "check_interval": 0.01,
        "max_wait": 1,
    },
    "katana": {
        "name": "katana",
        "explorer_url": "",
        "rpc_url": os.getenv("KATANA_RPC_URL", "http://127.0.0.1:5050"),
        "devnet": True,
        "check_interval": 0.01,
        "max_wait": 1,
    },
    "madara": {
        "name": "madara",
        "explorer_url": "",
        "rpc_url": os.getenv("MADARA_RPC_URL", "http://127.0.0.1:9944"),
        "devnet": False,
        "check_interval": 6,
        "max_wait": 30,
    },
    "sharingan": {
        "name": "sharingan",
        "explorer_url": "",
        "rpc_url": os.getenv("SHARINGAN_RPC_URL"),
        "devnet": False,
        "check_interval": 6,
        "max_wait": 30,
    },
    "kakarot-sepolia": {
        "name": "kakarot-sepolia",
        "explorer_url": "",
        "rpc_url": os.getenv("KAKAROT_SEPOLIA_RPC_URL"),
        "devnet": False,
        "check_interval": 6,
        "max_wait": 30,
    },
}

if os.getenv("STARKNET_NETWORK") is not None:
    if NETWORKS.get(os.environ["STARKNET_NETWORK"]) is not None:
        NETWORK = NETWORKS[os.environ["STARKNET_NETWORK"]]
    else:
        raise ValueError(
            f"STARKNET_NETWORK {os.environ['STARKNET_NETWORK']} given in env variable unknown"
        )
else:
    NETWORK = {
        "name": os.getenv("RPC_NAME", "custom-rpc"),
        "rpc_url": os.getenv("RPC_URL"),
        "explorer_url": "",
        "devnet": False,
        "check_interval": float(os.getenv("CHECK_INTERVAL", 0.1)),
        "max_wait": float(os.getenv("MAX_WAIT", 30)),
    }

prefix = NETWORK["name"].upper().replace("-", "_")
NETWORK["account_address"] = os.environ.get(f"{prefix}_ACCOUNT_ADDRESS")
if NETWORK["account_address"] is None:
    logger.warning(
        f"⚠️  {prefix}_ACCOUNT_ADDRESS not set, defaulting to ACCOUNT_ADDRESS"
    )
    NETWORK["account_address"] = os.getenv("ACCOUNT_ADDRESS")
NETWORK["private_key"] = os.environ.get(f"{prefix}_PRIVATE_KEY")
if NETWORK["private_key"] is None:
    logger.warning(f"⚠️  {prefix}_PRIVATE_KEY not set, defaulting to PRIVATE_KEY")
    NETWORK["private_key"] = os.getenv("PRIVATE_KEY")

RPC_CLIENT = FullNodeClient(node_url=NETWORK["rpc_url"])

try:
    response = requests.post(
        RPC_CLIENT.url,
        json={
            "jsonrpc": "2.0",
            "method": "starknet_chainId",
            "params": [],
            "id": 0,
        },
    )
    payload = json.loads(response.text)

    chain_id = int(payload["result"], 16)
except (requests.exceptions.ConnectionError, requests.exceptions.MissingSchema):
    chain_id = int.from_bytes(b"KKRT", "big")


class ChainId(IntEnum):
    chain_id = chain_id


NETWORK["chain_id"] = ChainId.chain_id

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
SOURCE_DIR = Path("src")
SOURCE_DIR_FIXTURES = Path("tests/fixtures")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}
CONTRACTS_FIXTURES = {p.stem: p for p in list(SOURCE_DIR_FIXTURES.glob("**/*.cairo"))}

BUILD_DIR = Path("build")
BUILD_DIR_FIXTURES = BUILD_DIR / "fixtures"
BUILD_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR_FIXTURES.mkdir(exist_ok=True, parents=True)
BUILD_DIR_SSJ = BUILD_DIR / "ssj"


class ArtifactType(Enum):
    cairo0 = 0
    cairo1 = 1


DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "kakarot", "is_account_contract": False},
    {"contract_name": "contract_account", "is_account_contract": True},
    {"contract_name": "uninitialized_account", "is_account_contract": False},
    {"contract_name": "EVM", "is_account_contract": False},
    {"contract_name": "OpenzeppelinAccount", "is_account_contract": True},
    {"contract_name": "ERC20", "is_account_contract": False},
    {"contract_name": "replace_class", "is_account_contract": False},
]
DECLARED_CONTRACTS = [
    {"contract_name": "kakarot", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "contract_account", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "uninitialized_account", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "EVM", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "OpenzeppelinAccount", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "Precompiles", "cairo_version": ArtifactType.cairo1},
    {"contract_name": "replace_class", "cairo_version": ArtifactType.cairo0},
]

EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
EVM_ADDRESS = (
    EVM_PRIVATE_KEY
    and keys.PrivateKey(
        bytes.fromhex(EVM_PRIVATE_KEY[2:])
    ).public_key.to_checksum_address()
)

if NETWORK.get("chain_id"):
    logger.info(
        f"ℹ️  Connected to CHAIN_ID {NETWORK['chain_id'].value.to_bytes(ceil(log(NETWORK['chain_id'].value, 256)), 'big')}"
    )
