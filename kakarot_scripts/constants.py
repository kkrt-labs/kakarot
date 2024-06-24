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
        "name": "mainnet",
        "explorer_url": "https://starkscan.co",
        "rpc_url": f"https://starknet-mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "l1_rpc_url": f"https://mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "chain_id": StarknetChainId.MAINNET,
    },
    "goerli": {
        "name": "starknet-goerli",
        "explorer_url": "https://testnet.starkscan.co",
        "rpc_url": f"https://starknet-goerli.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "l1_rpc_url": f"https://goerli.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "chain_id": StarknetChainId.GOERLI,
    },
    "sepolia": {
        "name": "starknet-sepolia",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": "https://starknet-sepolia.public.blastapi.io/rpc/v0_6",
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "chain_id": StarknetChainId.SEPOLIA_TESTNET,
        "check_interval": 5,
        "max_wait": 30,
    },
    "starknet-devnet": {
        "name": "starknet-devnet",
        "explorer_url": "",
        "rpc_url": "http://127.0.0.1:5050/rpc",
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
        "check_interval": 0.01,
        "max_wait": 1,
    },
    "katana": {
        "name": "katana",
        "explorer_url": "",
        "rpc_url": os.getenv("KATANA_RPC_URL", "http://127.0.0.1:5050"),
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
        "check_interval": 0.01,
        "max_wait": 2,
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
        chain_id = starknet_chain_id
except (
    requests.exceptions.ConnectionError,
    requests.exceptions.MissingSchema,
    requests.exceptions.InvalidSchema,
) as e:
    logger.info(
        f"⚠️  Could not get chain Id from {NETWORK['rpc_url']}: {e}, defaulting to KKRT"
    )
    chain_id = int.from_bytes(b"KKRT", "big")
    starknet_chain_id = int.from_bytes(b"KKRT", "big")


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
SOURCE_DIR = Path("src")
SOURCE_DIR_FIXTURES = Path("tests/fixtures")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}
CONTRACTS_FIXTURES = {p.stem: p for p in list(SOURCE_DIR_FIXTURES.glob("**/*.cairo"))}

BUILD_DIR = Path("build")
BUILD_DIR_FIXTURES = BUILD_DIR / "fixtures"
BUILD_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR_FIXTURES.mkdir(exist_ok=True, parents=True)
BUILD_DIR_SSJ = BUILD_DIR / "ssj"

DATA_DIR = Path("kakarot_scripts") / "data"


class ArtifactType(Enum):
    cairo0 = 0
    cairo1 = 1


DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "kakarot", "is_account_contract": False},
    {"contract_name": "account_contract", "is_account_contract": True},
    {"contract_name": "account_contract_fixture", "is_account_contract": True},
    {"contract_name": "uninitialized_account", "is_account_contract": False},
    {"contract_name": "EVM", "is_account_contract": False},
    {"contract_name": "OpenzeppelinAccount", "is_account_contract": True},
    {"contract_name": "ERC20", "is_account_contract": False},
    {"contract_name": "replace_class", "is_account_contract": False},
    {"contract_name": "Counter", "is_account_contract": False},
]
DECLARED_CONTRACTS = [
    {"contract_name": "kakarot", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "account_contract", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "account_contract_fixture", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "uninitialized_account", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "EVM", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "OpenzeppelinAccount", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "Cairo1Helpers", "cairo_version": ArtifactType.cairo1},
    {"contract_name": "Cairo1HelpersFixture", "cairo_version": ArtifactType.cairo1},
    {"contract_name": "replace_class", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "Counter", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "MockPragmaOracle", "cairo_version": ArtifactType.cairo1},
]

# PRE-EIP155 TX
MULTICALL3_DEPLOYER = "0x05f32b3cc3888453ff71b01135b34ff8e41263f2"
MULTICALL3_SIGNED_TX = bytes.fromhex(
    "f90f538085174876e800830f42408080b90f00608060405234801561001057600080fd5b50610ee0806100206000396000f3fe6080604052600436106100f35760003560e01c80634d2301cc1161008a578063a8b0574e11610059578063a8b0574e1461025a578063bce38bd714610275578063c3077fa914610288578063ee82ac5e1461029b57600080fd5b80634d2301cc146101ec57806372425d9d1461022157806382ad56cb1461023457806386d516e81461024757600080fd5b80633408e470116100c65780633408e47014610191578063399542e9146101a45780633e64a696146101c657806342cbb15c146101d957600080fd5b80630f28c97d146100f8578063174dea711461011a578063252dba421461013a57806327e86d6e1461015b575b600080fd5b34801561010457600080fd5b50425b6040519081526020015b60405180910390f35b61012d610128366004610a85565b6102ba565b6040516101119190610bbe565b61014d610148366004610a85565b6104ef565b604051610111929190610bd8565b34801561016757600080fd5b50437fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0140610107565b34801561019d57600080fd5b5046610107565b6101b76101b2366004610c60565b610690565b60405161011193929190610cba565b3480156101d257600080fd5b5048610107565b3480156101e557600080fd5b5043610107565b3480156101f857600080fd5b50610107610207366004610ce2565b73ffffffffffffffffffffffffffffffffffffffff163190565b34801561022d57600080fd5b5044610107565b61012d610242366004610a85565b6106ab565b34801561025357600080fd5b5045610107565b34801561026657600080fd5b50604051418152602001610111565b61012d610283366004610c60565b61085a565b6101b7610296366004610a85565b610a1a565b3480156102a757600080fd5b506101076102b6366004610d18565b4090565b60606000828067ffffffffffffffff8111156102d8576102d8610d31565b60405190808252806020026020018201604052801561031e57816020015b6040805180820190915260008152606060208201528152602001906001900390816102f65790505b5092503660005b8281101561047757600085828151811061034157610341610d60565b6020026020010151905087878381811061035d5761035d610d60565b905060200281019061036f9190610d8f565b6040810135958601959093506103886020850185610ce2565b73ffffffffffffffffffffffffffffffffffffffff16816103ac6060870187610dcd565b6040516103ba929190610e32565b60006040518083038185875af1925050503d80600081146103f7576040519150601f19603f3d011682016040523d82523d6000602084013e6103fc565b606091505b50602080850191909152901515808452908501351761046d577f08c379a000000000000000000000000000000000000000000000000000000000600052602060045260176024527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060445260846000fd5b5050600101610325565b508234146104e6576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f4d756c746963616c6c333a2076616c7565206d69736d6174636800000000000060448201526064015b60405180910390fd5b50505092915050565b436060828067ffffffffffffffff81111561050c5761050c610d31565b60405190808252806020026020018201604052801561053f57816020015b606081526020019060019003908161052a5790505b5091503660005b8281101561068657600087878381811061056257610562610d60565b90506020028101906105749190610e42565b92506105836020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff166105a66020850185610dcd565b6040516105b4929190610e32565b6000604051808303816000865af19150503d80600081146105f1576040519150601f19603f3d011682016040523d82523d6000602084013e6105f6565b606091505b5086848151811061060957610609610d60565b602090810291909101015290508061067d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060448201526064016104dd565b50600101610546565b5050509250929050565b43804060606106a086868661085a565b905093509350939050565b6060818067ffffffffffffffff8111156106c7576106c7610d31565b60405190808252806020026020018201604052801561070d57816020015b6040805180820190915260008152606060208201528152602001906001900390816106e55790505b5091503660005b828110156104e657600084828151811061073057610730610d60565b6020026020010151905086868381811061074c5761074c610d60565b905060200281019061075e9190610e76565b925061076d6020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff166107906040850185610dcd565b60405161079e929190610e32565b6000604051808303816000865af19150503d80600081146107db576040519150601f19603f3d011682016040523d82523d6000602084013e6107e0565b606091505b506020808401919091529015158083529084013517610851577f08c379a000000000000000000000000000000000000000000000000000000000600052602060045260176024527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060445260646000fd5b50600101610714565b6060818067ffffffffffffffff81111561087657610876610d31565b6040519080825280602002602001820160405280156108bc57816020015b6040805180820190915260008152606060208201528152602001906001900390816108945790505b5091503660005b82811015610a105760008482815181106108df576108df610d60565b602002602001015190508686838181106108fb576108fb610d60565b905060200281019061090d9190610e42565b925061091c6020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff1661093f6020850185610dcd565b60405161094d929190610e32565b6000604051808303816000865af19150503d806000811461098a576040519150601f19603f3d011682016040523d82523d6000602084013e61098f565b606091505b506020830152151581528715610a07578051610a07576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060448201526064016104dd565b506001016108c3565b5050509392505050565b6000806060610a2b60018686610690565b919790965090945092505050565b60008083601f840112610a4b57600080fd5b50813567ffffffffffffffff811115610a6357600080fd5b6020830191508360208260051b8501011115610a7e57600080fd5b9250929050565b60008060208385031215610a9857600080fd5b823567ffffffffffffffff811115610aaf57600080fd5b610abb85828601610a39565b90969095509350505050565b6000815180845260005b81811015610aed57602081850181015186830182015201610ad1565b81811115610aff576000602083870101525b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0169290920160200192915050565b600082825180855260208086019550808260051b84010181860160005b84811015610bb1578583037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe001895281518051151584528401516040858501819052610b9d81860183610ac7565b9a86019a9450505090830190600101610b4f565b5090979650505050505050565b602081526000610bd16020830184610b32565b9392505050565b600060408201848352602060408185015281855180845260608601915060608160051b870101935082870160005b82811015610c52577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa0888703018452610c40868351610ac7565b95509284019290840190600101610c06565b509398975050505050505050565b600080600060408486031215610c7557600080fd5b83358015158114610c8557600080fd5b9250602084013567ffffffffffffffff811115610ca157600080fd5b610cad86828701610a39565b9497909650939450505050565b838152826020820152606060408201526000610cd96060830184610b32565b95945050505050565b600060208284031215610cf457600080fd5b813573ffffffffffffffffffffffffffffffffffffffff81168114610bd157600080fd5b600060208284031215610d2a57600080fd5b5035919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81833603018112610dc357600080fd5b9190910192915050565b60008083357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112610e0257600080fd5b83018035915067ffffffffffffffff821115610e1d57600080fd5b602001915036819003821315610a7e57600080fd5b8183823760009101908152919050565b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc1833603018112610dc357600080fd5b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa1833603018112610dc357600080fdfea2646970667358221220bb2b5c71a328032f97c676ae39a1ec2148d3e5d6f73d95e9b17910152d61f16264736f6c634300080c00331ca0edce47092c0f398cebf3ffc267f05c8e7076e3b89445e0fe50f6332273d4569ba01b0b9d000e19b24c5869b0fc3b22b0d6fa47cd63316875cbbd577d76e6fde086"
)
ARACHNID_PROXY_DEPLOYER = "0x3fab184622dc19b6109349b94811493bf2a45362"
ARACHNID_PROXY_SIGNED_TX = bytes.fromhex(
    "f8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222"
)
CREATEX_DEPLOYER = "0xeD456e05CaAb11d66C4c797dD6c1D6f9A7F352b5"
CREATEX_SIGNED_TX = bytes.fromhex(
    json.loads((DATA_DIR / "createx_signed_tx.json").read_text())["tx"]
)

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
