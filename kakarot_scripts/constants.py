import json
import logging
import os
from enum import Enum, IntEnum
from pathlib import Path
from typing import Dict, List

import requests
from dotenv import load_dotenv
from eth_keys import keys
from starknet_py.net.account.account import Account
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair
from web3 import Web3

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv()

# Hardcode block gas limit to 7M
BLOCK_GAS_LIMIT = 7_000_000
DEFAULT_GAS_PRICE = int(1e9)
BEACON_ROOT_ADDRESS = "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02"


class NetworkType(Enum):
    PROD = "prod"
    DEV = "dev"
    STAGING = "staging"


NETWORKS = {
    "mainnet": {
        "name": "starknet-mainnet",
        "explorer_url": "https://starkscan.co",
        "rpc_url": f"https://rpc.nethermind.io/mainnet-juno/?apikey={os.getenv('NETHERMIND_API_KEY')}",
        "l1_rpc_url": f"https://mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "chain_id": StarknetChainId.MAINNET,
        "check_interval": 1,
        "max_wait": 10,
    },
    "sepolia": {
        "name": "starknet-sepolia",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": f"https://rpc.nethermind.io/sepolia-juno/?apikey={os.getenv('NETHERMIND_API_KEY')}",
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.STAGING,
        "chain_id": StarknetChainId.SEPOLIA,
        "check_interval": 1,
        "max_wait": 10,
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
        "check_interval": 0.01,
        "max_wait": 3,
        "relayers": [
            {
                "address": 0xB3FF441A68610B30FD5E2ABBF3A1548EB6BA6F3559F2862BF2DC757E5828CA,
                "private_key": 0x2BBF4F9FD0BBB2E60B0316C1FE0B76CF7A4D0198BD493CED9B8DF2A3A24D68A,
            },
            {
                "address": 0xE29882A1FCBA1E7E10CAD46212257FEA5C752A4F9B1B1EC683C503A2CF5C8A,
                "private_key": 0x14D6672DCB4B77CA36A887E9A11CD9D637D5012468175829E9C6E770C61642,
            },
            {
                "address": 0x29873C310FBEFDE666DC32A1554FEA6BB45EECC84F680F8A2B0A8FBB8CB89AF,
                "private_key": 0xC5B2FCAB997346F3EA1C00B002ECF6F382C5F9C9659A3894EB783C5320F912,
            },
            {
                "address": 0x2D71E9C974539BB3FFB4B115E66A23D0F62A641EA66C4016E903454C8753BBC,
                "private_key": 0x33003003001800009900180300D206308B0070DB00121318D17B5E6262150B,
            },
            {
                "address": 0x3EBB4767AAE1262F8EB28D9368DB5388CFE367F50552A8244123506F0B0BCCA,
                "private_key": 0x3E3979C1ED728490308054FE357A9F49CF67F80F9721F44CC57235129E090F4,
            },
            {
                "address": 0x541DA8F7F3AB8247329D22B3987D1FFB181BC8DC7F9611A6ECCEC3B0749A585,
                "private_key": 0x736ADBBCDAC7CC600F89051DB1ABBC16B9996B46F6B58A9752A11C1028A8EC8,
            },
            {
                "address": 0x56C155B624FDF6BFC94F7B37CF1DBEBB5E186EF2E4AB2762367CD07C8F892A1,
                "private_key": 0x6BF3604BCB41FED6C42BCCA5436EEB65083A982FF65DB0DC123F65358008B51,
            },
            {
                "address": 0x6162896D1D7AB204C7CCAC6DD5F8E9E7C25ECD5AE4FCB4AD32E57786BB46E03,
                "private_key": 0x1800000000300000180000000000030000000000003006001800006600,
            },
            {
                "address": 0x66EFB28AC62686966AE85095FF3A772E014E7FBF56D4C5F6FAC5606D4DDE23A,
                "private_key": 0x283D1E73776CD4AC1AC5F0B879F561BDED25ECEB2CC589C674AF0CEC41DF441,
            },
            {
                "address": 0x6B86E40118F29EBE393A75469B4D926C7A44C2E2681B6D319520B7C1156D114,
                "private_key": 0x1C9053C053EDF324AEC366A34C6901B1095B07AF69495BFFEC7D7FE21EFFB1B,
            },
        ],
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
    "sharingan": {
        "name": "sharingan",
        "explorer_url": "",
        "rpc_url": os.getenv("SHARINGAN_RPC_URL"),
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.PROD,
        "check_interval": 6,
        "max_wait": 30,
    },
    "kakarot-sepolia": {
        "name": "kakarot-sepolia",
        "explorer_url": "",
        "rpc_url": os.getenv("KAKAROT_SEPOLIA_RPC_URL"),
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "check_interval": 6,
        "max_wait": 360,
    },
    "kakarot-staging": {
        "name": "kakarot-staging",
        "explorer_url": "",
        "rpc_url": os.getenv("KAKAROT_STAGING_RPC_URL"),
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.STAGING,
        "check_interval": 1,
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
        chain_id = starknet_chain_id % (
            2**53 if NETWORK["name"] != "starknet-sepolia" else 2**32
        )
except (
    requests.exceptions.ConnectionError,
    requests.exceptions.MissingSchema,
    requests.exceptions.InvalidSchema,
) as e:
    logger.info(
        f"⚠️  Could not get chain Id from {NETWORK['rpc_url']}: {e}, defaulting to KKRT"
    )
    starknet_chain_id = int.from_bytes(b"KKRT", "big")
    chain_id = starknet_chain_id % (
        # TODO: remove once Kakarot is redeployed on sepolia
        2**53
        if NETWORK["name"] != "starknet-sepolia"
        else 2**32
    )


class ChainId(IntEnum):
    chain_id = chain_id
    starknet_chain_id = starknet_chain_id


NETWORK["chain_id"] = ChainId.chain_id

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
COINBASE = int(
    os.getenv("KAKAROT_COINBASE_RECIPIENT")
    or "0x20eB005C0b9c906691F885eca5895338E15c36De",
    16,
)
CAIRO_ZERO_DIR = Path("src")
CAIRO_DIR = Path("cairo1_contracts")
TESTS_DIR = Path("tests")

CONTRACTS = {
    p.stem: p
    for p in (
        list(CAIRO_ZERO_DIR.glob("**/*.cairo"))
        + list(TESTS_DIR.glob("**/*.cairo"))
        + list(CAIRO_DIR.glob("**/*.cairo"))
    )
}

BUILD_DIR = Path("build")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR_SSJ = BUILD_DIR / "ssj"

DATA_DIR = Path("kakarot_scripts") / "data"


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
    {"contract_name": "OpenzeppelinAccount", "is_account_contract": True},
    {"contract_name": "replace_class", "is_account_contract": False},
    {"contract_name": "StarknetToken", "is_account_contract": False},
    {"contract_name": "uninitialized_account_fixture", "is_account_contract": False},
    {"contract_name": "uninitialized_account", "is_account_contract": False},
    {"contract_name": "UniversalLibraryCaller", "is_account_contract": False},
]
DECLARED_CONTRACTS = [
    "account_contract",
    "Cairo1Helpers",
    "Cairo1HelpersFixture",
    "Counter",
    "ERC20",
    "EVM",
    "kakarot",
    "MockPragmaOracle",
    "OpenzeppelinAccount",
    "replace_class",
    "StarknetToken",
    "uninitialized_account_fixture",
    "uninitialized_account",
    "UniversalLibraryCaller",
]

# PRE-EIP155 TX
MULTICALL3_DEPLOYER = "0x05f32b3cc3888453ff71b01135b34ff8e41263f2"
MULTICALL3_SIGNED_TX = bytes.fromhex(
    json.loads((DATA_DIR / "signed_txs.json").read_text())["multicall3"]
)
ARACHNID_PROXY_DEPLOYER = "0x3fab184622dc19b6109349b94811493bf2a45362"
ARACHNID_PROXY_SIGNED_TX = bytes.fromhex(
    json.loads((DATA_DIR / "signed_txs.json").read_text())["arachnid"]
)
CREATEX_DEPLOYER = "0xeD456e05CaAb11d66C4c797dD6c1D6f9A7F352b5"
CREATEX_SIGNED_TX = bytes.fromhex(
    json.loads((DATA_DIR / "signed_txs.json").read_text())["createx"]
)

EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
EVM_ADDRESS = (
    EVM_PRIVATE_KEY
    and keys.PrivateKey(
        bytes.fromhex(EVM_PRIVATE_KEY[2:])
    ).public_key.to_checksum_address()
)

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


class RelayerPool:
    def __init__(self, relayers: List[Dict[str, int]]):
        self.relayer_accounts = [
            Account(
                address=relayer["address"],
                client=RPC_CLIENT,
                chain=ChainId.starknet_chain_id,
                key_pair=KeyPair.from_private_key(relayer["private_key"]),
            )
            for relayer in relayers
        ]
        self._index = 0

    def __next__(self) -> Account:
        relayer = self.relayer_accounts[self._index]
        self._index = (self._index + 1) % len(self.relayer_accounts)
        return relayer


NETWORK["relayers"] = RelayerPool(
    NETWORK.get(
        "relayers",
        (
            [
                {
                    "address": int(NETWORK["account_address"], 16),
                    "private_key": int(NETWORK["private_key"], 16),
                }
            ]
            if NETWORK["account_address"] is not None
            and NETWORK["private_key"] is not None
            else []
        ),
    )
)

logger.info(
    f"ℹ️  Connected to Starknet chain id {bytes.fromhex(f'{ChainId.starknet_chain_id.value:x}')} "
    f"and Kakarot chain id {bytes.fromhex(f'{ChainId.chain_id.value:x}')}"
)
