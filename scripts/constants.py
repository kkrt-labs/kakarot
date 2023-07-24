import json
import logging
import os
from enum import Enum
from math import ceil, log
from pathlib import Path

import requests
from dotenv import load_dotenv
from eth_keys import keys
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.models.chains import StarknetChainId

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv()


NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "explorer_url": "https://starkscan.co",
        "rpc_url": f"https://starknet-mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "gateway": "mainnet",
        "devnet": False,
        "chain_id": StarknetChainId.MAINNET,
    },
    "testnet": {
        "name": "testnet",
        "explorer_url": "https://testnet.starkscan.co",
        "rpc_url": f"https://starknet-goerli.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "gateway": "testnet",
        "devnet": False,
        "chain_id": StarknetChainId.TESTNET,
    },
    "testnet2": {
        "name": "testnet2",
        "explorer_url": "https://testnet-2.starkscan.co",
        "rpc_url": f"https://starknet-goerli2.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "gateway": "testnet2",
        "devnet": False,
        "chain_id": StarknetChainId.TESTNET2,
    },
    "starknet-devnet": {
        "name": "starknet-devnet",
        "explorer_url": "",
        "rpc_url": os.getenv("STARKNET_DEVNET_RPC_URL"),
        "devnet": True,
        "check_interval": 0.1,
        "max_wait": 1,
    },
    "katana": {
        "name": "katana",
        "explorer_url": "",
        "rpc_url": os.getenv("KATANA_RPC_URL"),
        "devnet": True,
        "check_interval": 0.1,
        "max_wait": 1,
    },
    "madara": {
        "name": "madara",
        "explorer_url": "",
        "rpc_url": os.getenv("MADARA_RPC_URL"),
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
        "name": "",
        "rpc_url": os.getenv("RPC_URL"),
        "explorer_url": "",
        "devnet": False,
        "check_interval": 6,
        "max_wait": 30,
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
GATEWAY_CLIENT = GatewayClient(NETWORK["gateway"]) if NETWORK.get("gateway") else None
CLIENT = GATEWAY_CLIENT if GATEWAY_CLIENT is not None else RPC_CLIENT

try:
    response = requests.post(
        RPC_CLIENT.url,
        json={
            "jsonrpc": "2.0",
            "method": f"starknet_chainId",
            "params": [],
            "id": 0,
        },
    )
    payload = json.loads(response.text)

    class ChainId(Enum):
        chain_id = int(payload["result"], 16)

    NETWORK["chain_id"] = ChainId.chain_id
except:
    pass

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
SOURCE_DIR = Path("src")
SOURCE_DIR_FIXTURES = Path("tests/fixtures")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}
CONTRACTS_FIXTURES = {p.stem: p for p in list(SOURCE_DIR_FIXTURES.glob("**/*.cairo"))}

BUILD_DIR = Path("build")
BUILD_DIR_FIXTURES = BUILD_DIR / "fixtures"
BUILD_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR_FIXTURES.mkdir(exist_ok=True, parents=True)
DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "kakarot", "is_account_contract": False},
    {"contract_name": "blockhash_registry", "is_account_contract": False},
    {"contract_name": "contract_account", "is_account_contract": False},
    {"contract_name": "externally_owned_account", "is_account_contract": True},
    {"contract_name": "proxy", "is_account_contract": False},
    {"contract_name": "EVM", "is_account_contract": False},
]

KAKAROT_CHAIN_ID = 1263227476  # KKRT (0x4b4b5254) in ASCII
EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
EVM_ADDRESS = (
    EVM_PRIVATE_KEY
    and keys.PrivateKey(
        bytes.fromhex(EVM_PRIVATE_KEY[2:])
    ).public_key.to_checksum_address()
)

if NETWORK.get("chain_id"):
    logger.info(
        f"ℹ️  Connected to CHAIN_ID {NETWORK['chain_id'].value.to_bytes(ceil(log(NETWORK['chain_id'].value, 256)), 'big')} "
        f"with {f'Gateway {GATEWAY_CLIENT.net}' if GATEWAY_CLIENT is not None else f'RPC {RPC_CLIENT.url}'}"
    )
