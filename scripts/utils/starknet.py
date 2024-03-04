import functools
import json
import logging
import random
import subprocess
from copy import deepcopy
from datetime import datetime
from functools import cache
from pathlib import Path
from typing import List, Union, cast

import requests
from async_lru import alru_cache
from marshmallow import EXCLUDE
from starknet_py.common import (
    create_casm_class,
    create_compiled_contract,
    create_sierra_compiled_contract,
)
from starknet_py.constants import DEFAULT_ENTRY_POINT_SELECTOR
from starknet_py.contract import Contract
from starknet_py.hash.address import compute_address
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.hash.class_hash import compute_class_hash
from starknet_py.hash.sierra_class_hash import compute_sierra_class_hash
from starknet_py.hash.transaction import TransactionHashPrefix, compute_transaction_hash
from starknet_py.hash.utils import message_signature
from starknet_py.net.account.account import Account
from starknet_py.net.client_models import Call, DeclareTransactionResponse
from starknet_py.net.full_node_client import _create_broadcasted_txn
from starknet_py.net.models.transaction import DeclareV1
from starknet_py.net.schemas.rpc import DeclareTransactionResponseSchema
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starkware.starknet.public.abi import get_selector_from_name

from scripts.constants import (
    BUILD_DIR,
    BUILD_DIR_FIXTURES,
    BUILD_DIR_SSJ,
    CONTRACTS,
    CONTRACTS_FIXTURES,
    DEPLOYMENTS_DIR,
    ETH_TOKEN_ADDRESS,
    NETWORK,
    RPC_CLIENT,
    SOURCE_DIR,
    ArtifactType,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Due to some fee estimation issues, we skip it in all the calls and set instead
# this hardcoded value. This has no impact apart from enforcing the signing wallet
# to have at least 0.1 ETH
_max_fee = int(1e17)


def int_to_uint256(value):
    value = int(value)
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return {"low": low, "high": high}


@alru_cache
async def get_starknet_account(
    address=None,
    private_key=None,
) -> Account:
    address = address or NETWORK["account_address"]
    if address is None:
        raise ValueError(
            "address was not given in arg nor in env variable, see README.md#Deploy"
        )
    address = int(address, 16) if isinstance(address, str) else address
    private_key = private_key or NETWORK["private_key"]
    if private_key is None:
        raise ValueError(
            "private_key was not given in arg nor in env variable, see README.md#Deploy"
        )
    key_pair = KeyPair.from_private_key(int(private_key, 16))

    public_key = None
    for selector in ["get_public_key", "getPublicKey", "getSigner"]:
        try:
            call = Call(
                to_addr=address,
                selector=get_selector_from_name(selector),
                calldata=[],
            )
            public_key = (
                await RPC_CLIENT.call_contract(call=call, block_hash="latest")
            )[0]
            break
        except Exception as err:
            message = str(err)
            if (
                "Client failed with code 40: Contract error." in message
                or "Client failed with code 40: Requested entry point was not found."
                in message
                or "Client failed with code 21: Invalid message selector." in message
                or "StarknetErrorCode.ENTRY_POINT_NOT_FOUND_IN_CONTRACT" in message
                or ("code 40" in message and "not found in contract" in message)
            ):
                continue
            else:
                logger.error(f"Raising for account at address {hex(address)}")
                raise err

    if public_key is not None:
        if key_pair.public_key != public_key:
            raise ValueError(
                f"Public key of account 0x{address:064x} is not consistent with provided private key"
            )
    else:
        logger.warning(
            f"⚠️ Unable to verify public key for account at address 0x{address:x}"
        )

    return Account(
        address=address,
        client=RPC_CLIENT,
        chain=NETWORK["chain_id"],
        key_pair=key_pair,
    )


@alru_cache
async def get_eth_contract(provider=None) -> Contract:
    return Contract(
        ETH_TOKEN_ADDRESS,
        json.loads((Path("scripts") / "utils" / "erc20.json").read_text())["abi"],
        provider or await get_starknet_account(),
    )


@cache
def get_contract(
    contract_name, address=None, provider=None, cairo_version=None
) -> Contract:
    return Contract(
        address or get_deployments()[contract_name]["address"],
        get_abi(contract_name, cairo_version),
        provider or RPC_CLIENT,
        cairo_version=get_artifact_version(contract_name).value,
    )


async def fund_address(
    address: Union[int, str], amount: float, funding_account=None, token_contract=None
):
    """
    Fund a given starknet address with {amount} ETH.
    """
    address = int(address, 16) if isinstance(address, str) else address
    amount = amount * 1e18
    if NETWORK["name"] == "starknet-devnet":
        response = requests.post(
            "http://127.0.0.1:5050/mint",
            json={"address": hex(address), "amount": int(amount)},
        )
        if response.status_code != 200:
            logger.error(f"Cannot mint token to {address}: {response.text}")
        else:
            logger.info(f"{amount / 1e18} ETH minted to {hex(address)}")
    else:
        account = funding_account or await get_starknet_account()
        eth_contract = token_contract or await get_eth_contract()
        balance = (await eth_contract.functions["balanceOf"].call(account.address)).balance  # type: ignore
        if balance < amount:
            raise ValueError(
                f"Cannot send {amount / 1e18} ETH from default account with current balance {balance / 1e18} ETH"
            )
        prepared = eth_contract.functions["transfer"].prepare_invoke_v1(
            address, int_to_uint256(amount)
        )
        tx = await prepared.invoke(max_fee=_max_fee)

        status = await wait_for_transaction(tx.hash)
        logger.info(
            f"{status} {amount / 1e18} ETH sent from {hex(account.address)} to {hex(address)}"
        )
        balance = (await eth_contract.functions["balanceOf"].call(address)).balance  # type: ignore
        logger.info(f"💰 Balance of {hex(address)}: {balance / 1e18}")


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
    try:
        return {
            name: {
                **deployment,
                "address": int(deployment["address"], 16),
                "tx": int(deployment["tx"], 16),
                "artifact": Path(deployment["artifact"]),
            }
            for name, deployment in json.load(
                open(DEPLOYMENTS_DIR / "deployments.json", "r")
            ).items()
        }
    except FileNotFoundError:
        return {}


@cache
def get_artifact(contract_name, cairo_version=None):
    if cairo_version is None:
        cairo_version = get_artifact_version(contract_name)
    if cairo_version == ArtifactType.cairo1:
        return (BUILD_DIR_SSJ / f"contracts_{contract_name}", ArtifactType.cairo1)

    return (
        (
            BUILD_DIR / f"{contract_name}.json"
            if not is_fixture_contract(contract_name)
            else BUILD_DIR_FIXTURES / f"{contract_name}.json"
        ),
        ArtifactType.cairo0,
    )


@cache
def get_abi(contract_name, cairo_version=None):
    artifact, cairo_version = get_artifact(contract_name, cairo_version)
    if cairo_version == ArtifactType.cairo1:
        artifact = artifact.with_suffix(".contract_class.json")

    return json.loads(artifact.read_text())["abi"]


def get_tx_url(tx_hash: int) -> str:
    return f"{NETWORK['explorer_url']}/tx/0x{tx_hash:064x}"


def is_fixture_contract(contract_name):
    return CONTRACTS_FIXTURES.get(contract_name) is not None


def get_artifact_version(contract_name):
    cairo_0 = contract_name in set(CONTRACTS_FIXTURES).union(set(CONTRACTS))
    cairo_1 = any(
        contract_name in str(artifact) for artifact in BUILD_DIR_SSJ.glob("*.json")
    )
    if cairo_0 and cairo_1:
        raise ValueError(f"Contract {contract_name} is ambiguous")
    if cairo_0:
        return ArtifactType.cairo0
    if cairo_1:
        return ArtifactType.cairo1
    raise ValueError(f"Cannot find artifact for contract {contract_name}")


def compile_contract(contract):
    logger.info(f"⏳ Compiling {contract['contract_name']}")
    start = datetime.now()
    is_fixture = is_fixture_contract(contract["contract_name"])
    artifact, cairo_version = get_artifact(contract["contract_name"])

    if cairo_version == ArtifactType.cairo1:
        raise NotImplementedError("SSJ compilation not implemented yet")

    output = subprocess.run(
        [
            "starknet-compile-deprecated",
            (
                CONTRACTS[contract["contract_name"]]
                if not is_fixture
                else CONTRACTS_FIXTURES[contract["contract_name"]]
            ),
            "--output",
            artifact,
            "--cairo_path",
            str(SOURCE_DIR),
            *(["--no_debug_info"] if not NETWORK["devnet"] else []),
            *(["--account_contract"] if contract["is_account_contract"] else []),
            *(["--disable_hint_validation"] if NETWORK["devnet"] else []),
        ],
        capture_output=True,
    )
    if output.returncode != 0:
        raise RuntimeError(output.stderr)

    elapsed = datetime.now() - start
    logger.info(
        f"✅ {contract['contract_name']} compiled in {elapsed.total_seconds():.2f}s"
    )


async def deploy_starknet_account(class_hash=None, private_key=None, amount=1):
    salt = random.randint(0, 2**251)
    private_key = private_key or NETWORK["private_key"]
    if private_key is None:
        raise ValueError(
            "private_key was not given in arg nor in env variable, see README.md#Deploy"
        )
    key_pair = KeyPair.from_private_key(int(private_key, 16))
    constructor_calldata = [key_pair.public_key]
    class_hash = class_hash or get_declarations()["OpenzeppelinAccount"]
    address = compute_address(
        salt=salt,
        class_hash=class_hash,
        constructor_calldata=constructor_calldata,
        deployer_address=0,
    )
    logger.info(f"ℹ️  Funding account {hex(address)} with {amount} ETH")
    await fund_address(address, amount=amount)
    logger.info("ℹ️  Deploying account")
    res = await Account.deploy_account_v1(
        address=address,
        class_hash=class_hash,
        salt=salt,
        key_pair=key_pair,
        client=RPC_CLIENT,
        chain=NETWORK["chain_id"],
        constructor_calldata=constructor_calldata,
        max_fee=_max_fee,
    )
    status = await wait_for_transaction(res.hash)
    logger.info(f"{status} Account deployed at address {hex(res.account.address)}")

    return {
        "address": res.account.address,
        "tx": res.hash,
        "artifact": get_artifact("OpenzeppelinAccount")[0],
    }


async def declare(contract):
    logger.info(f"ℹ️  Declaring {contract['contract_name']}")
    artifact, cairo_version = get_artifact(**contract)
    account = await get_starknet_account()

    if cairo_version == ArtifactType.cairo1:
        casm_compiled_contract = artifact.with_suffix(
            ".compiled_contract_class.json"
        ).read_text()
        sierra_compiled_contract = artifact.with_suffix(
            ".contract_class.json"
        ).read_text()

        casm_class = create_casm_class(casm_compiled_contract)
        class_hash = compute_casm_class_hash(casm_class)
        compiled_contract = create_sierra_compiled_contract(sierra_compiled_contract)
        deployed_class_hash = compute_sierra_class_hash(compiled_contract)

        try:
            await RPC_CLIENT.get_class_by_hash(deployed_class_hash)
            logger.info("✅ Class already declared, skipping")
            return deployed_class_hash
        except Exception:
            pass

        declare_v2_transaction = await account.sign_declare_v2(
            compiled_contract=sierra_compiled_contract,
            compiled_class_hash=class_hash,
            max_fee=_max_fee,
        )

        resp = await account.client.declare(transaction=declare_v2_transaction)
    else:
        contract_class = create_compiled_contract(
            compiled_contract=artifact.read_text()
        )
        class_hash = compute_class_hash(contract_class=deepcopy(contract_class))
        try:
            await RPC_CLIENT.get_class_by_hash(class_hash)
            logger.info("✅ Class already declared, skipping")
            return class_hash
        except Exception:
            pass

        tx_hash = compute_transaction_hash(
            tx_hash_prefix=TransactionHashPrefix.DECLARE,
            version=1,
            contract_address=account.address,
            entry_point_selector=DEFAULT_ENTRY_POINT_SELECTOR,
            calldata=[class_hash],
            max_fee=_max_fee,
            chain_id=account.signer.chain_id.value,
            additional_data=[await account.get_nonce()],
        )
        signature = message_signature(
            msg_hash=tx_hash, priv_key=account.signer.private_key
        )
        transaction = DeclareV1(
            contract_class=contract_class,
            sender_address=account.address,
            max_fee=_max_fee,
            signature=signature,
            nonce=await account.get_nonce(),
            version=1,
        )
        params = _create_broadcasted_txn(transaction=transaction)

        res = await RPC_CLIENT._client.call(
            method_name="addDeclareTransaction",
            params=[params],
        )
        resp = cast(
            DeclareTransactionResponse,
            DeclareTransactionResponseSchema().load(res, unknown=EXCLUDE),
        )
        deployed_class_hash = resp.class_hash

    status = await wait_for_transaction(resp.transaction_hash)

    logger.info(
        f"{status} {contract['contract_name']} class hash: {hex(resp.class_hash)}"
    )
    return deployed_class_hash


async def deploy(contract_name, *args):
    logger.info(f"ℹ️  Deploying {contract_name}")
    artifact, cairo_version = get_artifact(contract_name)
    declarations = get_declarations()
    if cairo_version == ArtifactType.cairo0:
        compiled_contract = Path(artifact).read_text()
        abi = json.loads(compiled_contract)["abi"]
    else:
        sierra_compiled_contract = artifact.with_suffix(
            ".contract_class.json"
        ).read_text()
        abi = json.loads(sierra_compiled_contract)["abi"]

    account = await get_starknet_account()
    deploy_result = await Contract.deploy_contract_v1(
        account=account,
        class_hash=declarations[contract_name],
        abi=abi,
        constructor_args=list(args),
        max_fee=_max_fee,
        cairo_version=cairo_version.value,
    )
    status = await wait_for_transaction(deploy_result.hash)
    logger.info(
        f"{status} {contract_name} deployed at: {hex(deploy_result.deployed_contract.address)}"
    )
    return {
        "address": deploy_result.deployed_contract.address,
        "tx": deploy_result.hash,
        "artifact": get_artifact(contract_name)[0],
    }


async def invoke_address(contract_address, function_name, *calldata, account=None):
    account = account or (await get_starknet_account())
    logger.info(
        f"ℹ️  Invoking {function_name}({json.dumps(calldata) if calldata else ''}) "
        f"at address {hex(contract_address)[:10]}"
    )
    return await account.execute_v1(
        Call(
            to_addr=contract_address,
            selector=get_selector_from_name(function_name),
            calldata=cast(List[int], calldata),
        ),
        max_fee=_max_fee,
    )


async def invoke_contract(
    contract_name, function_name, *inputs, address=None, account=None
):
    account = account or (await get_starknet_account())
    contract = get_contract(contract_name, address=address, provider=account)
    call = contract.functions[function_name].prepare_invoke_v1(*inputs)
    logger.info(
        f"ℹ️  Invoking {contract_name}.{function_name}({json.dumps(inputs) if inputs else ''})"
    )
    return await account.execute_v1(call, max_fee=_max_fee)


def set_block_gas_limit(kakarot, gas_limit: int):
    """
    Set the block gas limit.
    """

    tx = await kakarot.functions["set_block_gas_limit"].invoke_v1(gas_limit)
    await wait_for_transaction(
        tx.hash,
    )
    return tx


async def invoke(contract: Union[str, int], *args, **kwargs):
    """
    Invoke a contract specified:
     - either with a name (expect that a matching ABIs is to be found in the project artifacts)
       `invoke("MyContract", "foo")`
     - or with a plain address (in this later case, no parsing is done on the calldata)
       `invoke(0x1234, "foo")`.
    """
    response = await (
        invoke_address(contract, *args, **kwargs)
        if isinstance(contract, int)
        else invoke_contract(contract, *args, **kwargs)
    )
    status = await wait_for_transaction(response.transaction_hash)
    logger.info(
        f"{status} {contract}.{args[0]} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    return response.transaction_hash


async def call_address(contract_address, function_name, *calldata):
    account = await get_starknet_account()
    return await account.client.call_contract(
        Call(
            to_addr=contract_address,
            selector=get_selector_from_name(function_name),
            calldata=cast(List[int], calldata),
        )
    )


async def call_contract(contract_name, function_name, *inputs, address=None):
    contract = get_contract(contract_name, address=address)
    return await contract.functions[function_name].call(*inputs)


async def call(contract: Union[str, int], *args, **kwargs):
    """
    Call a contract specified:
     - either with a name (expect that a matching ABIs is to be found in the project artifacts)
     `call("MyContract", "foo")`
     - or with a plain address (in this later case, no parsing is done on the calldata)
     `call(0x1234, "foo")`.
    """
    return await (
        call_address(contract, *args, **kwargs)
        if isinstance(contract, int)
        else call_contract(contract, *args, **kwargs)
    )


@functools.wraps(RPC_CLIENT.wait_for_tx)
async def wait_for_transaction(tx_hash):
    try:
        await RPC_CLIENT.wait_for_tx(
            tx_hash,
            check_interval=NETWORK["check_interval"],
            retries=int(NETWORK["max_wait"] / NETWORK["check_interval"]),
        )
        return "✅"
    except Exception as e:
        logger.error(f"Error while waiting for transaction {tx_hash}: {e}")
        return "❌"
