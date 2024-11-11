import json
import logging
import os
from enum import Enum, IntEnum
from pathlib import Path

import requests
from dotenv import load_dotenv
from eth_keys import keys
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from web3 import Web3

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv(override=True)

BLOCK_GAS_LIMIT = 7_000_000
DEFAULT_GAS_PRICE = 1
BEACON_ROOT_ADDRESS = "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02"

# see https://gist.github.com/rekmarks/a47bd5f2525936c4b8eee31a16345553
MAX_SAFE_CHAIN_ID = 4503599627370476
# See https://github.com/kkrt-labs/kakarot/issues/1530
MAX_LEDGER_CHAIN_ID = 2**32 - 1

TOKEN_ADDRESSES_DIR = Path("starknet-addresses/bridged_tokens")


class NetworkType(Enum):
    PROD = "prod"
    DEV = "dev"
    STAGING = "staging"


NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "explorer_url": "https://starkscan.co",
        "rpc_url": f"https://rpc.nethermind.io/mainnet-juno/?apikey={os.getenv('NETHERMIND_API_KEY')}",
        "l1_rpc_url": f"https://mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "chain_id": StarknetChainId.MAINNET % MAX_LEDGER_CHAIN_ID,
        "check_interval": 1,
        "max_wait": 60,
        "class_hash": 0x061DAC032F228ABEF9C6626F995015233097AE253A7F72D68552DB02F2971B8F,
        "voyager_api_url": "https://api.voyager.online/beta",
        "argent_multisig_api": "https://cloud.argent-api.com/v1/multisig/starknet/mainnet",
        "token_addresses_file": TOKEN_ADDRESSES_DIR / "mainnet.json",
    },
    "sepolia": {
        "name": "sepolia",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": f"https://rpc.nethermind.io/sepolia-juno/?apikey={os.getenv('NETHERMIND_API_KEY')}",
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.STAGING,
        "chain_id": StarknetChainId.SEPOLIA % MAX_SAFE_CHAIN_ID,
        "check_interval": 1,
        "max_wait": 30,
        "class_hash": 0x061DAC032F228ABEF9C6626F995015233097AE253A7F72D68552DB02F2971B8F,
        "voyager_api_url": "https://sepolia-api.voyager.online/beta",
        "argent_multisig_api": "https://cloud.argent-api.com/v1/multisig/starknet/sepolia",
        "token_addresses_file": TOKEN_ADDRESSES_DIR / "sepolia.json",
    },
    "staging": {
        "name": "staging",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": f"https://rpc.nethermind.io/sepolia-juno/?apikey={os.getenv('NETHERMIND_API_KEY')}",
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.STAGING,
        "chain_id": StarknetChainId.SEPOLIA % MAX_SAFE_CHAIN_ID,
        "check_interval": 1,
        "max_wait": 30,
        "class_hash": 0x061DAC032F228ABEF9C6626F995015233097AE253A7F72D68552DB02F2971B8F,
        "voyager_api_url": "https://sepolia-api.voyager.online/beta",
        "argent_multisig_api": "https://cloud.argent-api.com/v1/multisig/starknet/sepolia",
        "token_addresses_file": TOKEN_ADDRESSES_DIR / "sepolia.json",
    },
    "staging-core": {
        "name": "staging-core",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": f"https://rpc.nethermind.io/sepolia-juno/?apikey={os.getenv('NETHERMIND_API_KEY')}",
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.STAGING,
        "chain_id": StarknetChainId.SEPOLIA % MAX_SAFE_CHAIN_ID,
        "check_interval": 1,
        "max_wait": 30,
        "class_hash": 0x061DAC032F228ABEF9C6626F995015233097AE253A7F72D68552DB02F2971B8F,
        "voyager_api_url": "https://sepolia-api.voyager.online/beta",
        "argent_multisig_api": "https://cloud.argent-api.com/v1/multisig/starknet/sepolia",
        "token_addresses_file": TOKEN_ADDRESSES_DIR / "sepolia.json",
    },
    "starknet-devnet": {
        "name": "starknet-devnet",
        "explorer_url": "",
        "rpc_url": "http://127.0.0.1:5050/rpc",
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
        "check_interval": 0.01,
        "max_wait": 3,
    },
    "katana": {
        "name": "katana",
        "explorer_url": "",
        "rpc_url": os.getenv("KATANA_RPC_URL", "http://127.0.0.1:5050"),
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
        "chain_id": int.from_bytes(b"KKRT", "big") % MAX_LEDGER_CHAIN_ID,
        "check_interval": 0.01,
        "max_wait": 3,
        "class_hash": 0x05400E90F7E0AE78BD02C77CD75527280470E2FE19C54970DD79DC37A9D3645C,
        "token_addresses_file": TOKEN_ADDRESSES_DIR / "sepolia.json",
    },
    "madara": {
        "name": "madara",
        "explorer_url": "",
        "rpc_url": os.getenv("MADARA_RPC_URL", "http://127.0.0.1:9944"),
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
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
elif os.getenv("RPC_URL") is not None:
    NETWORK = {
        "name": os.getenv("RPC_NAME", "custom-rpc"),
        "rpc_url": os.getenv("RPC_URL"),
        "explorer_url": "",
        "type": NetworkType.PROD,
        "check_interval": float(os.getenv("CHECK_INTERVAL", 0.1)),
        "max_wait": float(os.getenv("MAX_WAIT", 30)),
        "l1_rpc_url": os.getenv("L1_RPC_URL"),
    }
else:
    NETWORK = NETWORKS["katana"]

RPC_CLIENT = FullNodeClient(node_url=NETWORK["rpc_url"])
L1_RPC_PROVIDER = Web3(Web3.HTTPProvider(NETWORK["l1_rpc_url"]))
WEB3 = Web3()

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
    starknet_chain_id = int(payload["result"], 16)

    if WEB3.is_connected():
        chain_id = WEB3.eth.chain_id
    else:
        chain_id = NETWORK["chain_id"]
except (
    requests.exceptions.ConnectionError,
    requests.exceptions.MissingSchema,
    requests.exceptions.InvalidSchema,
) as e:
    logger.info(
        f"⚠️  Could not get chain Id from {NETWORK['rpc_url']}: {e}, defaulting to KKRT"
    )
    chain_id = starknet_chain_id = int.from_bytes(b"KKRT", "big")


class ChainId(IntEnum):
    chain_id = chain_id
    starknet_chain_id = starknet_chain_id


NETWORK["chain_id"] = ChainId.chain_id

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
STRK_TOKEN_ADDRESS = 0x04718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D

COINBASE = int(
    os.getenv("KAKAROT_COINBASE_RECIPIENT")
    or "0x20eB005C0b9c906691F885eca5895338E15c36De",  # Defaults to faucet on appchain sepolia
    16,
)
CAIRO_ZERO_DIR = Path("cairo_zero")
CAIRO_DIR = Path("cairo")
TESTS_DIR_CAIRO_ZERO = Path("cairo_zero/tests")
TESTS_DIR_END_TO_END = Path("tests")

CONTRACTS = {
    p.stem: p
    for p in (
        list(CAIRO_ZERO_DIR.glob("**/*.cairo"))
        + list(TESTS_DIR_CAIRO_ZERO.glob("**/*.cairo"))
        + list(TESTS_DIR_END_TO_END.glob("**/*.cairo"))
        + [x for x in list(CAIRO_DIR.glob("**/*.cairo")) if "kakarot-ssj" not in str(x)]
    )
}

BUILD_DIR = Path("build")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR_SSJ = BUILD_DIR / "ssj"

DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "account_contract", "is_account_contract": True},
    {"contract_name": "BalanceSender", "is_account_contract": False},
    {"contract_name": "Counter", "is_account_contract": False},
    {"contract_name": "ERC20", "is_account_contract": False},
    {"contract_name": "EVM", "is_account_contract": False},
    {"contract_name": "kakarot", "is_account_contract": False},
    {"contract_name": "MockPragmaOracle", "is_account_contract": False},
    {"contract_name": "MockPragmaSummaryStats", "is_account_contract": False},
    {"contract_name": "OpenzeppelinAccount", "is_account_contract": True},
    {"contract_name": "replace_class", "is_account_contract": False},
    {"contract_name": "StarknetToken", "is_account_contract": False},
    {"contract_name": "uninitialized_account_fixture", "is_account_contract": False},
    {"contract_name": "uninitialized_account", "is_account_contract": False},
    {"contract_name": "UniversalLibraryCaller", "is_account_contract": False},
    {"contract_name": "BenchmarkCairoCalls", "is_account_contract": False},
]
DECLARED_CONTRACTS = [
    "account_contract",
    "BalanceSender",
    "BenchmarkCairoCalls",
    "Cairo1Helpers",
    "Cairo1HelpersFixture",
    "Counter",
    "ERC20",
    "EVM",
    "kakarot",
    "MockPragmaOracle",
    "MockPragmaSummaryStats",
    "OpenzeppelinAccount",
    "replace_class",
    "StarknetToken",
    "uninitialized_account_fixture",
    "uninitialized_account",
    "UniversalLibraryCaller",
]

prefix = NETWORK["name"].upper().replace("-", "_")
EVM_PRIVATE_KEY = os.getenv(f"{prefix}_EVM_PRIVATE_KEY")
if EVM_PRIVATE_KEY is None:
    logger.warning(
        f"⚠️  {prefix}_EVM_PRIVATE_KEY not set, defaulting to EVM_PRIVATE_KEY"
    )
    EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
    if EVM_PRIVATE_KEY is None:
        raise ValueError("EVM_PRIVATE_KEY not set")
EVM_ADDRESS = keys.PrivateKey(
    bytes.fromhex(EVM_PRIVATE_KEY[2:])
).public_key.to_checksum_address()

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


kakarot_chain_ascii = bytes.fromhex(f"{ChainId.chain_id.value:014x}").lstrip(b"\x00")
logger.info(
    f"ℹ️  Connected to Starknet chain id {bytes.fromhex(f'{ChainId.starknet_chain_id.value:x}')} "
    f"and Kakarot chain id {kakarot_chain_ascii}\n\nNetwork: {NETWORK['name']}\n"
)
