import functools
import json
import logging
import os
import re
import subprocess
from pathlib import Path
from typing import Union

import requests
from caseconverter import snakecase
from starknet_py.contract import Contract
from starknet_py.net import AccountClient
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starkware.starknet.wallets.account import DEFAULT_ACCOUNT_DIR

from scripts.constants import (
    BUILD_DIR,
    CHAIN_ID,
    CONTRACTS,
    DEPLOYMENTS_DIR,
    GATEWAY_CLIENT,
    NETWORK,
    SOURCE_DIR,
    STARKNET_NETWORK,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR.mkdir(exist_ok=True, parents=True)


def int_to_uint256(value):
    value = int(value)
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return {"low": low, "high": high}


async def create_account():
    env = os.environ.copy()
    env[
        "STARKNET_WALLET"
    ] = "starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount"
    env["STARKNET_NETWORK"] = STARKNET_NETWORK
    logger.info("⏳ Creating account")
    output = subprocess.run(
        ["starknet", "new_account", "--account", "kakarot"],
        env=env,
        capture_output=True,
    )
    if output.returncode != 0:
        raise Exception(output.stderr.decode())
    account_address = re.search(
        r"account address: (.*)", (output.stdout.decode() + output.stderr.decode()).lower()  # type: ignore
    )[1]
    input(f"Send ETH to {account_address} and press enter to continue")
    output = subprocess.run(
        [
            "starknet",
            "deploy_account",
            "--account",
            "kakarot",
            "--gateway_url",
            f"{GATEWAY_CLIENT.net}/gateway",
            "--feeder_gateway_url",
            f"{GATEWAY_CLIENT.net}/feeder_gateway",
        ],
        env=env,
        capture_output=True,
    )
    if output.returncode != 0:
        raise Exception(output.stderr.decode())
    transaction_hash = re.search(
        r"transaction hash: (.*)", (output.stdout.decode() + output.stderr.decode()).lower()  # type: ignore
    )[1]
    await GATEWAY_CLIENT.wait_for_tx(transaction_hash)


def get_default_account() -> AccountClient:
    accounts = json.load(
        open(list(Path(DEFAULT_ACCOUNT_DIR).expanduser().glob("*.json"))[0])
    )
    account = accounts.get(STARKNET_NETWORK, {}).get("kakarot")
    if account is None:
        raise ValueError(
            f"No account found for NETWORK {NETWORK} (KeyError: {STARKNET_NETWORK})"
        )

    return AccountClient(
        address=account["address"],
        client=GATEWAY_CLIENT,
        supported_tx_version=1,
        chain=CHAIN_ID,
        key_pair=KeyPair(
            private_key=int(account["private_key"], 16),
            public_key=int(account["public_key"], 16),
        ),
    )


def get_account(
    address=None,
    private_key=None,
) -> AccountClient:
    if NETWORK == "devnet":
        # Hard-coded values when running starknet-devnet with seed = 0
        return AccountClient(
            address="0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a",
            client=GATEWAY_CLIENT,
            supported_tx_version=1,
            chain=CHAIN_ID,
            key_pair=KeyPair(
                private_key=int("0xe3e70682c2094cac629f6fbed82c07cd", 16),
                public_key=int(
                    "0x7e52885445756b313ea16849145363ccb73fb4ab0440dbac333cf9d13de82b9",
                    16,
                ),
            ),
        )

    return AccountClient(
        address=address or os.environ["ACCOUNT_ADDRESS"],
        client=GATEWAY_CLIENT,
        supported_tx_version=1,
        chain=CHAIN_ID,
        key_pair=KeyPair.from_private_key(
            private_key or int(os.environ["PRIVATE_KEY"])
        ),
    )


async def get_eth_contract() -> Contract:
    address = (
        int(requests.get(f"{GATEWAY_CLIENT.net}/fee_token").json()["address"], 16)
        if NETWORK == "devnet"
        else 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
    )
    account = get_account()
    return await Contract.from_address(
        address,
        account,
    )


async def get_contract(contract_name) -> Contract:
    return await Contract.from_address(
        get_deployments()[contract_name]["address"],
        get_account(),
    )


async def fund_address(address: Union[int, str], amount: int):
    address = int(address, 16) if isinstance(address, str) else address
    account = get_account()
    eth_contract = await get_eth_contract()
    balance = (await eth_contract.functions["balanceOf"].call(account.address)).balance  # type: ignore
    if balance / 1e18 < amount:
        raise ValueError(
            f"Cannot send {amount} ETH from default account with current balance {balance / 1e18} ETH"
        )
    tx = await eth_contract.functions["transfer"].invoke(
        address, int_to_uint256(amount * 1e18), max_fee=int(1e16)
    )
    await tx.wait_for_acceptance()
    logger.info(f"{amount} ETH sent from {hex(account.address)} to {address}")


def dump_declarations(declarations):
    json.dump(
        {name: hex(class_hash) for name, class_hash in declarations.items()},
        open(DEPLOYMENTS_DIR / "declarations.json", "w"),
        indent=2,
    )


def get_declarations():
    return {
        name: int(class_hash, 16)
        for name, class_hash in json.load(
            open(DEPLOYMENTS_DIR / "declarations.json")
        ).items()
    }


def dump_deployments(deployments):
    json.dump(
        {
            name: {
                **deployment,
                "address": hex(deployment["address"]),
                "tx": hex(deployment["tx"]),
                "artifact": str(deployment["artifact"]),
            }
            for name, deployment in deployments.items()
        },
        open(DEPLOYMENTS_DIR / "deployments.json", "w"),
        indent=2,
    )


def get_deployments():
    return json.load(open(DEPLOYMENTS_DIR / "deployments.json", "r"))


def get_artifact(contract_name):
    return BUILD_DIR / f"{contract_name}.json"


def get_abi(contract_name):
    return BUILD_DIR / f"{contract_name}_abi.json"


def get_alias(contract_name):
    return snakecase(contract_name)


def compile_contract(contract_name):
    contract_file = CONTRACTS.get(contract_name)
    if contract_file is None:
        raise ValueError(
            f"Cannot find {SOURCE_DIR}/**/{contract_name}.cairo in {os.getcwd()}"
        )
    output = subprocess.run(
        [
            "starknet-compile",
            contract_file,
            "--output",
            BUILD_DIR / f"{contract_name}.json",
            "--abi",
            BUILD_DIR / f"{contract_name}_abi.json",
            *(["--disable_hint_validation"] if NETWORK == "devnet" else []),
        ],
        capture_output=True,
    )
    if output.returncode != 0:
        raise RuntimeError(output.stderr)


async def declare(contract_name):
    logger.info(f"⏳ Declaring {contract_name}")
    account = get_account()
    artifact = get_artifact(contract_name)
    declare_transaction = await account.sign_declare_transaction(
        compiled_contract=Path(artifact).read_text(), max_fee=int(1e16)
    )
    resp = await account.declare(transaction=declare_transaction)
    await account.wait_for_tx(resp.transaction_hash)
    logger.info(f"✅ {contract_name} class hash: {hex(resp.class_hash)}")
    return resp.class_hash


async def deploy(contract_name, *args):
    logger.info(f"⏳ Deploying {contract_name}")
    abi = json.loads(Path(get_abi(contract_name)).read_text())
    account = get_account()
    artifact = get_artifact(contract_name)
    # TODO: upgrade to starknet-devnet latest to remove this
    # TODO: In current version, UDC is not available
    if NETWORK == "devnet":
        deploy_result = await Contract.deploy(
            client=account,
            compiled_contract=Path(artifact).read_text(),
            constructor_args=list(args),
        )
    else:
        deploy_result = await Contract.deploy_contract(
            account=account,
            class_hash=get_declarations()[contract_name],
            abi=abi,
            constructor_args=list(args),
            max_fee=int(1e16),
        )
    await deploy_result.wait_for_acceptance()
    logger.info(
        f"✅ {contract_name} deployed at: {hex(deploy_result.deployed_contract.address)}"
    )
    return {
        "address": deploy_result.deployed_contract.address,
        "tx": deploy_result.hash,
        "artifact": get_artifact(contract_name),
    }


async def invoke(contract_name, function_name, *inputs, address=None):
    account = get_account()
    deployments = get_deployments()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
    )
    call = contract.functions[function_name].prepare(*inputs, max_fee=int(1e16))
    logger.info(f"⏳ Invoking {contract_name}.{function_name}({call.arguments})")
    response = await account.execute(call, max_fee=int(1e16))
    logger.info(
        f"⏳ {contract_name}.{function_name} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    await account.wait_for_tx(response.transaction_hash)
    return response.transaction_hash


async def call(contract_name, function_name, *inputs, address=None):
    deployments = get_deployments()
    account = get_account()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
    )
    return await contract.functions[function_name].call(*inputs)


@functools.wraps(GATEWAY_CLIENT.wait_for_tx)
async def wait_for_transaction(*args, **kwargs):
    return await GATEWAY_CLIENT.wait_for_tx(*args, **kwargs)
