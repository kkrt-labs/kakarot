import os
import re
from enum import Enum
from pathlib import Path
import requests
import io
import zipfile
import json
import pandas as pd

from dotenv import load_dotenv
from starknet_py.net.gateway_client import GatewayClient

load_dotenv()

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
EVM_ADDRESS = os.getenv("EVM_ADDRESS")
EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
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
    "mainnet": "alpha-mainnet",
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


CHAIN_ID = getattr(ChainId, NETWORK)
KAKAROT_CHAIN_ID = 1263227476  # KKRT (0x4b4b5254) in ASCII

DEPLOYMENTS_DIR = Path("deployments")
DEPLOYMENTS_NETWORK_DIR = Path("deployments") / NETWORK
BUILD_DIR = Path("build")
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}

ACCOUNT_ADDRESS = (
    os.environ.get(f"{NETWORK.upper()}_ACCOUNT_ADDRESS")
    or os.environ["ACCOUNT_ADDRESS"]
)
PRIVATE_KEY = (
    os.environ.get(f"{NETWORK.upper()}_PRIVATE_KEY") or os.environ["PRIVATE_KEY"]
)


def pull_deployments():
    response = requests.get(
        "https://api.github.com/repos/sayajin-labs/kakarot/actions/artifacts"
    )
    artifacts = (
        pd.DataFrame(
            [
                {**artifact["workflow_run"], **artifact}
                for artifact in response.json()["artifacts"]
            ]
        )
        .reindex(["head_branch", "updated_at", "archive_download_url", "name"], axis=1)
        .sort_values(["head_branch", "updated_at"], ascending=False)
    )

    main_artifacts = artifacts[artifacts["head_branch"] == "main"]
    deployement_artifacts = main_artifacts[main_artifacts["name"] == "deployments"]

    if "main" not in deployement_artifacts.head_branch.tolist():
        raise Exception(f"No deployment artifacts found for base branch main")

    response = requests.get(
        deployement_artifacts.archive_download_url.tolist()[0],
        headers={"Authorization": f"Bearer {os.getenv('GITHUB_TOKEN')}"},
    )
    z = zipfile.ZipFile(io.BytesIO(response.content))
    z.extractall(DEPLOYMENTS_DIR)


pull_deployments()
deployments = json.load(open(DEPLOYMENTS_NETWORK_DIR / "deployments.json", "r"))

KAKAROT_ADDRESS = deployments["kakarot"]["address"]
