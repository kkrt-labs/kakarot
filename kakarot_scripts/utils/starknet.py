import asyncio
import functools
import json
import logging
import random
import re
import subprocess
from collections import defaultdict, namedtuple
from copy import deepcopy
from datetime import datetime
from functools import cache
from typing import Iterable, List, Optional, Union, cast

import requests
from async_lru import alru_cache
from marshmallow import EXCLUDE
from starknet_py.common import (
    create_casm_class,
    create_compiled_contract,
    create_sierra_compiled_contract,
)
from starknet_py.constants import DEFAULT_DEPLOYER_ADDRESS, DEFAULT_ENTRY_POINT_SELECTOR
from starknet_py.contract import Contract
from starknet_py.hash.address import compute_address
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.hash.class_hash import compute_class_hash
from starknet_py.hash.sierra_class_hash import compute_sierra_class_hash
from starknet_py.hash.transaction import TransactionHashPrefix, compute_transaction_hash
from starknet_py.hash.utils import message_signature
from starknet_py.net.account.account import Account, _parse_calls
from starknet_py.net.client_errors import ClientError
from starknet_py.net.client_models import (
    Call,
    DeclareTransactionResponse,
    SentTransactionResponse,
)
from starknet_py.net.full_node_client import _create_broadcasted_txn
from starknet_py.net.models.transaction import DeclareV1, InvokeV1
from starknet_py.net.schemas.rpc import (
    DeclareTransactionResponseSchema,
    SentTransactionSchema,
)
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.udc_deployer.deployer import Deployer
from starkware.starknet.public.abi import get_selector_from_name

from kakarot_scripts.constants import (
    BUILD_DIR,
    BUILD_DIR_SSJ,
    CAIRO_DIR,
    CAIRO_ZERO_DIR,
    CONTRACTS,
    DEPLOYMENTS_DIR,
    ETH_TOKEN_ADDRESS,
    NETWORK,
    RPC_CLIENT,
    ChainId,
    NetworkType,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Due to some fee estimation issues, we skip it in all the calls and set instead
# this hardcoded value. This has no impact apart from enforcing the signing wallet
# to have at least 0.1 ETH
_max_fee = int(0.05e18)

# Global variables for lazy execution and multisig accounts
_logs = defaultdict(list)
_lazy_execute = defaultdict(bool)
_multisig_account = defaultdict(bool)

# Dict to store selector to name mapping because argent api requires the name but calls have selector
_selector_to_name = {get_selector_from_name("deployContract"): "deployContract"}


def store_selector(_get_selector_from_name):
    def wrapped(func_name):
        selector = _get_selector_from_name(func_name)
        _selector_to_name[selector] = func_name
        return selector

    return wrapped


get_selector_from_name = store_selector(get_selector_from_name)

Artifact = namedtuple("Artifact", ["sierra", "casm"])


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

    public_keys = None
    for selector in [
        "get_public_key",
        "getPublicKey",
        "getSigner",
        "get_owner",
        "get_signers",
    ]:
        try:
            call = Call(
                to_addr=address,
                selector=get_selector_from_name(selector),
                calldata=[],
            )
            public_keys = await RPC_CLIENT.call_contract(
                call=call, block_hash="pending"
            )
            break
        except Exception as err:
            message = str(err)
            if (
                "Client failed with code 40: Contract error." in message
                or "Client failed with code 40: Requested entry point was not found."
                in message
                or "Invalid message selector." in message
                or "StarknetErrorCode.ENTRY_POINT_NOT_FOUND_IN_CONTRACT" in message
                or ("code 40" in message and "not found in contract" in message)
                or "{'error': 'Invalid message selector'}" in message
            ):
                continue
            else:
                logger.error(f"Raising for account at address {hex(address)}")
                raise err

    if public_keys is not None:
        if key_pair.public_key not in public_keys:
            raise ValueError(
                f"Public key of account 0x{address:064x} is not consistent with provided private key"
            )
        if len(public_keys) > 1:
            register_multisig_account(address)
            logger.info("ℹ️ Account is a multisig")
    else:
        logger.warning(
            f"⚠️ Unable to verify public key for account at address 0x{address:x}"
        )

    return Account(
        address=address,
        client=RPC_CLIENT,
        chain=ChainId.starknet_chain_id,
        key_pair=key_pair,
    )


@alru_cache
async def get_eth_contract(provider=None) -> Contract:
    return Contract(
        ETH_TOKEN_ADDRESS,
        get_abi("ERC20"),
        provider or next(NETWORK["relayers"]),
        cairo_version=0,
    )


@cache
def get_contract(contract_name, address=None, provider=None) -> Contract:
    return Contract(
        address or get_deployments()[contract_name],
        get_abi(contract_name),
        provider or RPC_CLIENT,
        cairo_version=get_cairo_version(contract_name),
    )


async def fund_address(
    address: Union[int, str], amount: float, funding_account=None, token_contract=None
):
    """
    Fund a given starknet address with {amount} ETH.
    """
    address = int(address, 16) if isinstance(address, str) else address
    amount = int(amount * 1e18)
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
        account = funding_account or next(NETWORK["relayers"])
        eth_contract = token_contract or await get_eth_contract(account)
        balance = await get_balance(account.address, eth_contract)
        if balance < amount:
            raise ValueError(
                f"Cannot send {amount / 1e18} ETH from default account with current balance {balance / 1e18} ETH"
            )
        prepared = eth_contract.functions["transfer"].prepare_invoke_v1(address, amount)
        tx = await prepared.invoke(max_fee=_max_fee)

        status = await wait_for_transaction(tx.hash)
        logger.info(
            f"{status} {amount / 1e18} ETH sent from {hex(account.address)} to {hex(address)}"
        )
        balance = (await eth_contract.functions["balanceOf"].call(address)).balance  # type: ignore
        logger.info(f"💰 Balance of {hex(address)}: {balance / 1e18}")


async def get_balance(address: Union[int, str], token_contract=None):
    """
    Get the ETH balance of a starknet address.
    """
    address = int(address, 16) if isinstance(address, str) else address
    eth_contract = token_contract or await get_eth_contract()
    return (await eth_contract.functions["balanceOf"].call(address)).balance  # type: ignore


def dump_class_hashes(class_hashes):
    json.dump(
        {name: hex(class_hash) for name, class_hash in class_hashes.items()},
        open(BUILD_DIR / "class_hashes.json", "w"),
        indent=2,
    )


def get_class_hashes():
    return {
        name: int(class_hash, 16)
        for name, class_hash in json.load(open(BUILD_DIR / "class_hashes.json")).items()
    }


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
        {name: hex(deployment) for name, deployment in deployments.items()},
        open(DEPLOYMENTS_DIR / "deployments.json", "w"),
        indent=2,
    )


def get_deployments():
    try:
        return {
            name: int(deployment, 16)
            for name, deployment in json.load(
                open(DEPLOYMENTS_DIR / "deployments.json", "r")
            ).items()
        }
    except FileNotFoundError:
        return {}


@cache
def get_artifact(contract_name):
    # Cairo 0 artifacts
    artifacts = list(BUILD_DIR.glob(f"*{contract_name}*.json"))
    if artifacts:
        return Artifact(sierra=None, casm=artifacts[0])

    # Cairo 1 artifacts
    artifacts = list(BUILD_DIR_SSJ.glob(f"**/*{contract_name}.*.json")) or [
        artifact
        for artifact in list(CAIRO_DIR.glob(f"**/*{contract_name}.*.json"))
        if "test" not in str(artifact)
    ]
    if artifacts:
        sierra, casm = (
            artifacts
            if "sierra.json" in artifacts[0].name
            or ".contract_class.json" in artifacts[0].name
            else artifacts[::-1]
        )
        return Artifact(sierra=sierra, casm=casm)

    raise FileNotFoundError(f"No artifact found for {contract_name}")


@cache
def get_abi(contract_name):
    artifact = get_artifact(contract_name)
    return json.loads(
        (artifact.sierra if artifact.sierra else artifact.casm).read_text()
    )["abi"]


@cache
def get_cairo_version(contract_name):
    return get_artifact(contract_name).sierra is not None


@cache
def get_tx_url(tx_hash: int) -> str:
    return f"{NETWORK['explorer_url']}/tx/0x{tx_hash:064x}"


def compile_contract(contract):
    logger.info(f"⏳ Compiling {contract['contract_name']}")
    start = datetime.now()
    contract_path = CONTRACTS.get(contract["contract_name"]) or CONTRACTS.get(
        re.sub("(?!^)([A-Z]+)", r"_\1", contract["contract_name"]).lower()
    )

    if contract_path.is_relative_to(CAIRO_DIR):
        output = subprocess.run(
            "scarb build", shell=True, cwd=contract_path.parent, capture_output=True
        )
    else:
        output = subprocess.run(
            [
                "starknet-compile-deprecated",
                contract_path,
                "--output",
                BUILD_DIR / f"{contract['contract_name']}.json",
                "--cairo_path",
                str(CAIRO_ZERO_DIR),
                *(
                    ["--no_debug_info"]
                    if NETWORK["type"] is not NetworkType.DEV
                    else []
                ),
                *(["--account_contract"] if contract["is_account_contract"] else []),
                *(
                    ["--disable_hint_validation"]
                    if NETWORK["type"] is NetworkType.DEV
                    else []
                ),
            ],
            capture_output=True,
        )

    if output.returncode != 0:
        raise RuntimeError(
            f"❌ {contract['contract_name']} raised:\n{output.stderr}.\nOutput:\n{output.stdout}"
        )

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
    class_hash = class_hash or NETWORK.get(
        "class_hash", get_declarations().get("OpenzeppelinAccount")
    )
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
        constructor_calldata=constructor_calldata,
        max_fee=_max_fee,
    )
    status = await wait_for_transaction(res.hash)
    logger.info(f"{status} Account deployed at: 0x{res.account.address:064x}")

    return {
        "address": res.account.address,
        "tx": res.hash,
        "artifact": get_artifact("OpenzeppelinAccount")[0],
    }


def compute_deployed_class_hash(contract_name):
    artifact = get_artifact.__wrapped__(contract_name)

    if artifact.sierra is not None:
        sierra_compiled_contract = artifact.sierra.read_text()
        compiled_contract = create_sierra_compiled_contract(sierra_compiled_contract)
        return compute_sierra_class_hash(compiled_contract)
    else:
        contract_class = create_compiled_contract(
            compiled_contract=artifact.casm.read_text()
        )
        return compute_class_hash(contract_class=deepcopy(contract_class))


async def declare(contract_name):
    logger.info(f"ℹ️  Declaring {contract_name}")
    artifact = get_artifact(contract_name)
    deployed_class_hash = get_class_hashes()[contract_name]
    try:
        await RPC_CLIENT.get_class_by_hash(deployed_class_hash)
        logger.info("✅ Class already declared, skipping")
        return deployed_class_hash
    except Exception:
        pass

    account = next(NETWORK["relayers"])

    if artifact.sierra is not None:
        casm_compiled_contract = artifact.casm.read_text()
        sierra_compiled_contract = artifact.sierra.read_text()
        casm_class = create_casm_class(casm_compiled_contract)
        class_hash = compute_casm_class_hash(casm_class)
        declare_v2_transaction = await account.sign_declare_v2(
            compiled_contract=sierra_compiled_contract,
            compiled_class_hash=class_hash,
            max_fee=_max_fee,
        )

        resp = await account.client.declare(transaction=declare_v2_transaction)
    else:
        contract_class = create_compiled_contract(
            compiled_contract=artifact.casm.read_text()
        )

        tx_hash = compute_transaction_hash(
            tx_hash_prefix=TransactionHashPrefix.DECLARE,
            version=1,
            contract_address=account.address,
            entry_point_selector=DEFAULT_ENTRY_POINT_SELECTOR,
            calldata=[deployed_class_hash],
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

    logger.info(f"{status} {contract_name} class hash: {hex(resp.class_hash)}")
    return deployed_class_hash


async def deploy(contract_name, *args):
    deployments = get_deployments()
    if deployments.get(contract_name):
        try:
            deployed_class_hash = await RPC_CLIENT.get_class_hash_at(
                deployments[contract_name]
            )
            latest_class_hash = get_declarations().get(contract_name)
            if latest_class_hash == deployed_class_hash:
                logger.info(f"✅ {contract_name} already deployed, skipping")
                return deployments[contract_name]
        except ClientError:
            pass

    abi = get_abi(contract_name)
    declarations = get_declarations()

    account = await get_starknet_account()

    deployer = Deployer(
        deployer_address=DEFAULT_DEPLOYER_ADDRESS,
        account_address=account.address,
    )
    deploy_call, address = deployer.create_contract_deployment(
        class_hash=declarations[contract_name],
        abi=abi,
        calldata=list(args),
        cairo_version=get_cairo_version(contract_name),
    )
    logger.info(f"ℹ️  Deploying {contract_name} at: 0x{address:064x}")
    await execute_v1(account, deploy_call)
    return address


def register_lazy_account(account_address):
    _lazy_execute[account_address] = True


def remove_lazy_account(account_address):
    _lazy_execute.pop(account_address, None)


def register_multisig_account(account_address):
    _multisig_account[account_address] = True


def lazy_execute(execute):
    @functools.wraps(execute)
    async def wrapper(account, calls):
        if not isinstance(calls, Iterable):
            calls = [calls]

        if _lazy_execute[account.address]:
            _logs[account].extend(calls)
            return

        return await execute(account, calls)

    return wrapper


async def execute_calls():
    global _logs
    for _account, _calls in _logs.items():
        logger.info(
            f"ℹ️  Executing {len(_calls)} calls with account 0x{_account.address:064x}"
        )
        await execute_v1.__wrapped__(_account, _calls)

    _logs = defaultdict(list)


@lazy_execute
async def execute_v1(account, calls):
    calldata = _parse_calls(await account.cairo_version, calls)
    msg_hash = compute_transaction_hash(
        tx_hash_prefix=TransactionHashPrefix.INVOKE,
        version=1,
        contract_address=account.address,
        entry_point_selector=DEFAULT_ENTRY_POINT_SELECTOR,
        calldata=calldata,
        max_fee=_max_fee,
        chain_id=NETWORK["chain_id"].starknet_chain_id,
        additional_data=[await account.get_nonce()],
    )
    signature = message_signature(
        msg_hash=msg_hash, priv_key=account.signer.private_key, seed=None
    )
    transaction = InvokeV1(
        version=1,
        signature=signature,
        nonce=await account.get_nonce(),
        max_fee=_max_fee,
        sender_address=account.address,
        calldata=calldata,
    )

    if _multisig_account[account.address]:
        data = {
            "creator": f"0x{account.signer.public_key:064x}",
            "transaction": {
                "maxFee": hex(transaction.max_fee),
                "nonce": hex(transaction.nonce),
                "version": hex(transaction.version),
                "calls": [
                    {
                        "contractAddress": hex(call.to_addr),
                        "calldata": [str(data) for data in call.calldata],
                        "entrypoint": _selector_to_name[call.selector],
                    }
                    for call in calls
                ],
            },
            "starknetSignature": dict(zip(["r", "s"], [hex(v) for v in signature])),
        }
        response = requests.post(
            f"{NETWORK['argent_multisig_api']}/0x{account.address:064x}/request",
            json=data,
        )
        content = response.json()["content"]
        transaction_id = content["id"]
        status = content["state"]
        while status not in {"TX_ACCEPTED_L2", "REVERTED"}:
            response = requests.get(
                f"{NETWORK['argent_multisig_api']}/0x{account.address:064x}/request"
            )
            contents = [
                content
                for content in response.json()["content"]
                if content["id"] == transaction_id
            ]
            if len(contents) == 0:
                raise Exception("Transaction not found")
            content = contents[0]
            status = content["state"]
            await asyncio.sleep(5)
        return {
            "transaction_hash": content["transactionHash"],
            "status": content["state"],
        }

    params = _create_broadcasted_txn(transaction=transaction)
    res = cast(
        SentTransactionResponse,
        SentTransactionSchema().load(
            await RPC_CLIENT._client.call(
                method_name="addInvokeTransaction",
                params={"invoke_transaction": params},
            )
        ),
    )

    status = await wait_for_transaction(res.transaction_hash)
    logger.info(f"{status}: 0x{res.transaction_hash:064x}")
    return res


async def invoke(
    contract_id: Union[str, int],
    function_name: str,
    *calldata,
    address=None,
    account=None,
) -> Optional[str]:
    """
    Invoke a contract specified:
     - either with a name (expect that a matching ABIs is to be found in the project artifacts)
       `invoke("MyContract", "foo")`
     - or with a plain address (in this later case, no parsing is done on the calldata)
       `invoke(0x1234, "foo")`.
    """
    account = account or await get_starknet_account()
    logger.info(
        f"ℹ️  Invoking {contract_id}.{function_name}({(json.dumps(calldata) if len(json.dumps(calldata)) < 100 else '...') if calldata else ''})"
    )
    if isinstance(contract_id, int):
        call = Call(
            to_addr=contract_id,
            selector=get_selector_from_name(function_name),
            calldata=cast(List[int], calldata),
        )
    else:
        contract = get_contract(contract_id, address=address, provider=account)
        _selector_to_name[get_selector_from_name(function_name)] = function_name
        call = contract.functions[function_name].prepare_invoke_v1(*calldata)

    response = await execute_v1(account, call)
    return getattr(response, "transaction_hash", None)


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
        logger.error(f"Error while waiting for transaction 0x{tx_hash:064x}: {e}")
        return "❌"
