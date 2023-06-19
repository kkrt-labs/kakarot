import functools
import json
import logging
import random
import subprocess
import time
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Union, cast

import requests
from caseconverter import snakecase
from marshmallow import EXCLUDE
from starknet_py.common import create_compiled_contract
from starknet_py.contract import Contract, InvokeResult
from starknet_py.hash.address import compute_address
from starknet_py.hash.class_hash import compute_class_hash
from starknet_py.hash.transaction import compute_declare_transaction_hash
from starknet_py.hash.utils import message_signature
from starknet_py.net.account.account import Account, _add_signature_to_transaction
from starknet_py.net.client_models import (
    Call,
    DeclareTransactionResponse,
    TransactionStatus,
)
from starknet_py.net.full_node_client import _create_broadcasted_txn
from starknet_py.net.models.transaction import Declare, Invoke
from starknet_py.net.schemas.rpc import DeclareTransactionResponseSchema
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starkware.starknet.public.abi import get_selector_from_name

from scripts.constants import (
    ACCOUNT_ADDRESS,
    BUILD_DIR,
    CHAIN_ID,
    CONTRACTS,
    DEPLOYMENTS_DIR,
    ETH_TOKEN_ADDRESS,
    NETWORK,
    PRIVATE_KEY,
    RPC_CLIENT,
    SOURCE_DIR,
    STARKSCAN_URL,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

_account_address = ACCOUNT_ADDRESS
_private_key = PRIVATE_KEY


def int_to_uint256(value):
    value = int(value)
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return {"low": low, "high": high}


async def get_starknet_account(
    address=None,
    private_key=None,
) -> Account:
    global _account_address
    global _private_key
    address = address or _account_address
    if address is None:
        raise ValueError(
            "address was not given in arg nor in env variable, see README.md#Deploy"
        )
    address = int(address, 16)
    private_key = private_key or _private_key
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
        except Exception as err:
            if (
                err.message == "Client failed with code 40: Contract error."
                or err.message
                == "Client failed with code 21: Invalid message selector."
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
        chain=CHAIN_ID,
        key_pair=key_pair,
    )


async def get_eth_contract() -> Contract:
    # TODO: use .from_address when katana implements getClass
    return Contract(
        ETH_TOKEN_ADDRESS,
        json.loads((Path("scripts") / "utils" / "erc20.json").read_text())["abi"],
        await get_starknet_account(),
    )


async def get_contract(contract_name) -> Contract:
    # TODO: use .from_address when katana implements getClass
    return Contract(
        get_deployments()[contract_name]["address"],
        json.loads(get_artifact(contract_name).read_text())["abi"],
        await get_starknet_account(),
    )


async def fund_address(address: Union[int, str], amount: float):
    """
    Fund a given starknet address with {amount} ETH
    """
    address = int(address, 16) if isinstance(address, str) else address
    amount = amount * 1e18
    if NETWORK == "devnet":
        response = requests.post(
            f"http://127.0.0.1:5050/mint",
            json={"address": hex(address), "amount": amount},
        )
        if response.status_code != 200:
            logger.error(f"Cannot mint token to {address}: {response.text}")
        logger.info(f"{amount / 1e18} ETH minted to {hex(address)}")
    else:
        account = await get_starknet_account()
        eth_contract = await get_eth_contract()
        balance = (await eth_contract.functions["balanceOf"].call(account.address)).balance  # type: ignore
        if balance < amount:
            raise ValueError(
                f"Cannot send {amount / 1e18} ETH from default account with current balance {balance / 1e18} ETH"
            )
        prepared = eth_contract.functions["transfer"].prepare(
            address, int_to_uint256(amount)
        )
        # TODO: remove when madara has a regular default account
        if NETWORK == "madara" and account.address == 1:
            transaction = Invoke(
                calldata=[
                    prepared.to_addr,
                    prepared.selector,
                    len(prepared.calldata),
                    *prepared.calldata,
                ],
                signature=[],
                max_fee=0,
                version=1,
                nonce=await account.get_nonce(),
                sender_address=account.address,
            )
            _add_signature_to_transaction(
                transaction, account.signer.sign_transaction(transaction)
            )
            response = await RPC_CLIENT.send_transaction(transaction)
            tx = InvokeResult(
                hash=response.transaction_hash,  # noinspection PyTypeChecker
                _client=prepared._client,
                contract=prepared._contract_data,
                invoke_transaction=transaction,
            )
        else:
            tx = await prepared.invoke(max_fee=int(1e17))

        await wait_for_transaction(tx.hash)
        balance = (await eth_contract.functions["balanceOf"].call(address)).balance  # type: ignore
        logger.info(
            f"{amount / 1e18} ETH sent from {hex(account.address)} to {hex(address)}; new balance {balance / 1e18}"
        )


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


def get_alias(contract_name):
    return snakecase(contract_name)


def get_tx_url(tx_hash: int) -> str:
    return f"{STARKSCAN_URL}/tx/0x{tx_hash:064x}"


def compile_contract(contract):
    output = subprocess.run(
        [
            "starknet-compile-deprecated",
            CONTRACTS[contract["contract_name"]],
            "--output",
            BUILD_DIR / f"{contract['contract_name']}.json",
            "--cairo_path",
            str(SOURCE_DIR),
            *(["--no_debug_info"] if NETWORK != "devnet" else []),
            *(["--account_contract"] if contract["is_account_contract"] else []),
            *(["--disable_hint_validation"] if NETWORK == "devnet" else []),
        ],
        capture_output=True,
    )
    if output.returncode != 0:
        raise RuntimeError(output.stderr)

    def _convert_offset_to_hex(obj):
        if isinstance(obj, list):
            return [_convert_offset_to_hex(i) for i in obj]
        if isinstance(obj, dict):
            return {key: _convert_offset_to_hex(obj[key]) for key, value in obj.items()}
        if isinstance(obj, int) and obj >= 0:
            return hex(obj)
        return obj

    compiled = json.loads((BUILD_DIR / f"{contract['contract_name']}.json").read_text())
    compiled = {
        **compiled,
        "entry_points_by_type": _convert_offset_to_hex(
            compiled["entry_points_by_type"]
        ),
    }
    json.dump(
        compiled, open(BUILD_DIR / f"{contract['contract_name']}.json", "w"), indent=2
    )


async def deploy_starknet_account(private_key=None, amount=1) -> Account:
    compile_contract(
        {"contract_name": "OpenzeppelinAccount", "is_account_contract": True}
    )
    class_hash = await declare("OpenzeppelinAccount")
    salt = random.randint(0, 2**251)
    global _private_key
    global _account_address
    private_key = private_key or _private_key
    if private_key is None:
        raise ValueError(
            "private_key was not given in arg nor in env variable, see README.md#Deploy"
        )
    key_pair = KeyPair.from_private_key(int(private_key, 16))
    constructor_calldata = [key_pair.public_key]
    address = compute_address(
        salt=salt,
        class_hash=class_hash,
        constructor_calldata=constructor_calldata,
        deployer_address=0,
    )
    logger.info(f"ℹ️  Funding account {hex(address)} with {amount} ETH")
    await fund_address(address, amount=amount)
    logger.info(f"ℹ️  Deploying account")
    res = await Account.deploy_account(
        address=address,
        class_hash=class_hash,
        salt=salt,
        key_pair=key_pair,
        client=RPC_CLIENT,
        chain=CHAIN_ID,
        constructor_calldata=constructor_calldata,
        max_fee=int(1e17),
    )
    status = await wait_for_transaction(res.hash)
    if status == TransactionStatus.REJECTED:
        logger.warning("⚠️  Transaction REJECTED")

    logger.info(f"✅ Account deployed at address {hex(res.account.address)}")
    _account_address = hex(res.account.address)
    _private_key = hex(key_pair.private_key)
    return res.account


async def declare(contract_name):
    logger.info(f"ℹ️  Declaring {contract_name}")
    artifact = get_artifact(contract_name)
    compiled_contract = Path(artifact).read_text()
    contract_class = create_compiled_contract(compiled_contract=compiled_contract)
    class_hash = compute_class_hash(contract_class=deepcopy(contract_class))
    try:
        await RPC_CLIENT.get_class_by_hash(class_hash)
        logger.info(f"✅ Class already declared, skipping")
        return class_hash
    except Exception:
        pass
    account = await get_starknet_account()
    transaction = Declare(
        contract_class=contract_class,
        sender_address=account.address,
        max_fee=int(1e17),
        signature=[],
        nonce=await account.get_nonce(),
        version=1,
    )
    tx_hash = compute_declare_transaction_hash(
        contract_class=deepcopy(transaction.contract_class),
        chain_id=account.signer.chain_id.value,
        sender_address=account.address,
        max_fee=transaction.max_fee,
        version=transaction.version,
        nonce=transaction.nonce,
    )
    signature = message_signature(msg_hash=tx_hash, priv_key=account.signer.private_key)
    transaction = _add_signature_to_transaction(transaction, signature)
    params = _create_broadcasted_txn(transaction=transaction)

    res = await RPC_CLIENT._client.call(
        method_name="addDeclareTransaction",
        params=[params],
    )
    resp = cast(
        DeclareTransactionResponse,
        DeclareTransactionResponseSchema().load(res, unknown=EXCLUDE),
    )

    await wait_for_transaction(resp.transaction_hash)
    logger.info(f"✅ {contract_name} class hash: {hex(resp.class_hash)}")
    return resp.class_hash


async def deploy(contract_name, *args):
    logger.info(f"ℹ️  Deploying {contract_name}")
    abi = json.loads(Path(get_artifact(contract_name)).read_text())["abi"]
    account = await get_starknet_account()
    deploy_result = await Contract.deploy_contract(
        account=account,
        class_hash=get_declarations()[contract_name],
        abi=abi,
        constructor_args=list(args),
        max_fee=int(1e17),
    )
    await wait_for_transaction(deploy_result.hash)
    logger.info(
        f"✅ {contract_name} deployed at: {hex(deploy_result.deployed_contract.address)}"
    )
    return {
        "address": deploy_result.deployed_contract.address,
        "tx": deploy_result.hash,
        "artifact": get_artifact(contract_name),
    }


async def invoke(contract_name, function_name, *inputs, address=None):
    account = await get_starknet_account()
    deployments = get_deployments()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
    )
    call = contract.functions[function_name].prepare(*inputs, max_fee=int(1e17))
    logger.info(f"ℹ️  Invoking {contract_name}.{function_name}({json.dumps(inputs)})")
    response = await account.execute(call, max_fee=int(1e17))
    await wait_for_transaction(response.transaction_hash)
    logger.info(
        f"✅ {contract_name}.{function_name} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    return response.transaction_hash


async def call(contract_name, function_name, *inputs, address=None):
    deployments = get_deployments()
    account = await get_starknet_account()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
    )
    return await contract.functions[function_name].call(*inputs)


# TODO: use RPC_CLIENT when RPC wait_for_tx is fixed, see https://github.com/kkrt-labs/kakarot/issues/586
# TODO: Currently, the first ping often throws "transaction not found"
@functools.wraps(RPC_CLIENT.wait_for_tx)
async def wait_for_transaction(*args, **kwargs):
    """
    We need to write this custom hacky wait_for_transaction instead of using the one from starknet-py
    because the RPCs don't know RECEIVED, PENDING and REJECTED states currently
    """
    start = datetime.now()
    elapsed = 0
    check_interval = kwargs.get(
        "check_interval",
        0.1 if NETWORK in ["devnet", "katana"] else 1 if NETWORK == "madara" else 15,
    )
    max_wait = kwargs.get(
        "max_wait", 60 * 5 if NETWORK not in ["devnet", "katana", "madara"] else 30
    )
    transaction_hash = args[0] if args else kwargs["tx_hash"]
    status = None
    logger.info(f"⏳ Waiting for tx {get_tx_url(transaction_hash)}")
    while (
        status not in [TransactionStatus.ACCEPTED_ON_L2, TransactionStatus.REJECTED]
        and elapsed < max_wait
    ):
        logger.info(f"ℹ️  Current status: {status}")
        logger.info(f"ℹ️  Sleeping for {check_interval}s")
        time.sleep(check_interval)
        response = requests.post(
            RPC_CLIENT.url,
            json={
                "jsonrpc": "2.0",
                "method": f"starknet_getTransactionReceipt",
                "params": {"transaction_hash": hex(transaction_hash)},
                "id": 0,
            },
        )
        payload = json.loads(response.text)
        if payload.get("error"):
            if payload["error"]["message"] != "Transaction hash not found":
                logger.warn(json.dumps(payload["error"]))
                break
        status = payload.get("result", {}).get("status")
        if status is not None:
            status = TransactionStatus(status)
        elapsed = (datetime.now() - start).total_seconds()
    return status
