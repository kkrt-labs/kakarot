import functools
import json
import logging
from pathlib import Path
from types import MethodType
from typing import Any, Dict, List, Optional, Tuple, Union, cast

import rlp
from async_lru import alru_cache
from eth_abi import decode
from eth_abi.exceptions import InsufficientDataBytes
from eth_account import Account as EvmAccount
from eth_account.typed_transactions import TypedTransaction
from eth_keys import keys
from eth_utils import keccak
from eth_utils.address import to_checksum_address
from hexbytes import HexBytes
from starknet_py.net.account.account import Account
from starknet_py.net.client_errors import ClientError
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starkware.starknet.public.abi import starknet_keccak
from web3 import Web3
from web3._utils.abi import get_abi_output_types, map_abi_data
from web3._utils.events import get_event_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS
from web3.contract import Contract as Web3Contract
from web3.contract.contract import ContractEvents
from web3.exceptions import LogTopicError, MismatchedABI, NoABIFunctionsFound
from web3.types import LogReceipt

from kakarot_scripts.constants import (
    DEFAULT_GAS_PRICE,
    DEPLOYMENTS_DIR,
    EVM_ADDRESS,
    EVM_PRIVATE_KEY,
    NETWORK,
    RPC_CLIENT,
    WEB3,
    ChainId,
)
from kakarot_scripts.utils.starknet import _max_fee
from kakarot_scripts.utils.starknet import call as _call_starknet
from kakarot_scripts.utils.starknet import fund_address as _fund_starknet_address
from kakarot_scripts.utils.starknet import get_balance
from kakarot_scripts.utils.starknet import get_contract as _get_starknet_contract
from kakarot_scripts.utils.starknet import get_deployments as _get_starknet_deployments
from kakarot_scripts.utils.starknet import invoke as _invoke_starknet
from kakarot_scripts.utils.starknet import wait_for_transaction
from kakarot_scripts.utils.uint256 import int_to_uint256
from tests.utils.constants import TRANSACTION_GAS_LIMIT
from tests.utils.helpers import pack_calldata, rlp_encode_signed_data

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class EvmTransactionError(Exception):
    pass


class StarknetTransactionError(Exception):
    pass


@functools.lru_cache()
def get_solidity_artifacts(
    contract_app: str,
    contract_name: str,
):
    import toml

    try:
        foundry_file = toml.loads(
            (Path(__file__).parents[2] / "foundry.toml").read_text()
        )
    except (NameError, FileNotFoundError):
        foundry_file = toml.loads(Path("foundry.toml").read_text())

    src_path = Path(foundry_file["profile"]["default"]["src"])
    all_compilation_outputs = [
        json.load(open(file))
        for file in Path(foundry_file["profile"]["default"]["out"]).glob(
            f"**/{contract_name}.json"
        )
    ]
    if len(all_compilation_outputs) == 1:
        target_compilation_output = all_compilation_outputs[0]
    else:
        target_solidity_file_path = list(
            (src_path / contract_app).glob(f"**/{contract_name}.sol")
        )
        if len(target_solidity_file_path) != 1:
            raise ValueError(
                f"Cannot locate a unique {contract_name} in {contract_app}"
            )

        target_compilation_output = [
            compilation
            for compilation in all_compilation_outputs
            if compilation["metadata"]["settings"]["compilationTarget"].get(
                str(target_solidity_file_path[0])
            )
        ]

        if len(target_compilation_output) != 1:
            raise ValueError(
                f"Cannot locate a unique compilation output for target {target_solidity_file_path[0]}: "
                f"found {len(target_compilation_output)} outputs:\n{target_compilation_output}"
            )
        target_compilation_output = target_compilation_output[0]

    def process_link_references(
        link_references: Dict[str, Dict[str, Any]]
    ) -> Dict[str, Dict[str, Any]]:
        return {
            Path(file_path)
            .relative_to(src_path)
            .parts[0]: {
                library_name: references
                for library_name, references in libraries.items()
            }
            for file_path, libraries in link_references.items()
        }

    return {
        "bytecode": {
            "object": target_compilation_output["bytecode"]["object"],
            "linkReferences": process_link_references(
                target_compilation_output["bytecode"].get("linkReferences", {})
            ),
        },
        "bytecode_runtime": {
            "object": target_compilation_output["deployedBytecode"]["object"],
            "linkReferences": process_link_references(
                target_compilation_output["deployedBytecode"].get("linkReferences", {})
            ),
        },
        "abi": target_compilation_output["abi"],
        "name": contract_name,
    }


async def get_contract(
    contract_app: str,
    contract_name: str,
    address=None,
    caller_eoa: Optional[Account] = None,
) -> Web3Contract:
    artifacts = get_solidity_artifacts(contract_app, contract_name)

    bytecode, bytecode_runtime = await link_libraries(artifacts)

    contract = cast(
        Web3Contract,
        WEB3.eth.contract(
            address=to_checksum_address(address) if address is not None else address,
            abi=artifacts["abi"],
            bytecode=bytecode,
        ),
    )
    contract.bytecode_runtime = HexBytes(bytecode_runtime)

    try:
        for fun in contract.functions:
            setattr(contract, fun, MethodType(_wrap_kakarot(fun, caller_eoa), contract))
    except NoABIFunctionsFound:
        pass
    contract.events.parse_events = MethodType(_parse_events, contract.events)
    return contract


def get_contract_sync(
    contract_app: str,
    contract_name: str,
    address=None,
    caller_eoa: Optional[Account] = None,
) -> Web3Contract:

    artifacts = get_solidity_artifacts(contract_app, contract_name)

    contract = cast(
        Web3Contract,
        WEB3.eth.contract(
            address=to_checksum_address(address) if address is not None else address,
            abi=artifacts["abi"],
            bytecode=artifacts["bytecode"]["object"],
        ),
    )
    contract.bytecode_runtime = HexBytes(artifacts["bytecode_runtime"]["object"])

    try:
        for fun in contract.functions:
            setattr(contract, fun, MethodType(_wrap_kakarot(fun, caller_eoa), contract))
    except NoABIFunctionsFound:
        pass
    contract.events.parse_events = MethodType(_parse_events, contract.events)
    return contract


@alru_cache()
async def get_or_deploy_library(library_app: str, library_name: str) -> str:
    """
    Deploy a solidity library if not already deployed and return its address.

    Args:
    ----
        library_app (str): The application name of the library.
        library_name (str): The name of the library.

    Returns:
    -------
        str: The deployed library address as a hexstring with the '0x' prefix.

    """
    library_contract = await deploy(library_app, library_name)
    logger.info(f"ℹ️  Deployed {library_name} at address {library_contract.address}")
    return library_contract.address


async def link_libraries(artifacts: Dict[str, Any]) -> Tuple[str, str]:
    """
    Process an artifacts bytecode by linking libraries with their deployed addresses.

    Args:
    ----
        artifacts (Dict[str, Any]): The contract artifacts containing bytecode and link references.

    Returns:
    -------
        Tuple[str, str]: The processed bytecode and runtime bytecode.

    """

    async def process_bytecode(bytecode_type: str) -> str:
        bytecode_obj = artifacts[bytecode_type]
        current_bytecode = bytecode_obj["object"][2:]
        link_references = bytecode_obj.get("linkReferences", {})

        for library_app, libraries in link_references.items():
            for library_name, references in libraries.items():
                library_address = await get_or_deploy_library(library_app, library_name)

                for ref in references:
                    start, length = ref["start"] * 2, ref["length"] * 2
                    placeholder = current_bytecode[start : start + length]
                    current_bytecode = current_bytecode.replace(
                        placeholder, library_address[2:].lower()
                    )

                logger.info(
                    f"ℹ️  Replaced {library_name} in {bytecode_type} with address 0x{library_address}"
                )

        return current_bytecode

    bytecode = await process_bytecode("bytecode")
    bytecode_runtime = await process_bytecode("bytecode_runtime")

    return bytecode, bytecode_runtime


async def deploy(
    contract_app: str, contract_name: str, *args, **kwargs
) -> Web3Contract:
    logger.info(f"⏳ Deploying {contract_name}")
    caller_eoa = kwargs.pop("caller_eoa", None)
    contract = await get_contract(contract_app, contract_name, caller_eoa=caller_eoa)
    max_fee = kwargs.pop("max_fee", None)
    value = kwargs.pop("value", 0)
    gas_price = kwargs.pop("gas_price", DEFAULT_GAS_PRICE)
    receipt, response, success, _ = await eth_send_transaction(
        to=0,
        gas=int(TRANSACTION_GAS_LIMIT),
        data=contract.constructor(*args, **kwargs).data_in_transaction,
        caller_eoa=caller_eoa,
        max_fee=max_fee,
        value=value,
        gas_price=gas_price,
    )
    if success == 0:
        raise EvmTransactionError(bytes(response))

    if WEB3.is_connected():
        evm_address = int(receipt.contractAddress or receipt.to, 16)
        starknet_address = (
            await _call_starknet("kakarot", "get_starknet_address", evm_address)
        ).contract_address
    else:
        starknet_address, evm_address = response
    contract.address = Web3.to_checksum_address(f"0x{evm_address:040x}")
    contract.starknet_address = starknet_address
    logger.info(f"✅ {contract_name} deployed at: {contract.address}")

    return contract


async def deploy_details(
    contract_app: str, contract_name: str, *args, **kwargs
) -> Web3Contract:
    contract = await deploy(contract_app, contract_name, *args, **kwargs)
    return {
        "address": int(contract.address, 16),
        "starknet_address": contract.starknet_address,
    }


def dump_deployments(deployments):
    json.dump(
        {
            name: {
                **deployment,
                "address": hex(deployment["address"]),
                "starknet_address": hex(deployment["starknet_address"]),
            }
            for name, deployment in deployments.items()
        },
        open(DEPLOYMENTS_DIR / "kakarot_deployments.json", "w"),
        indent=2,
    )


def get_deployments():
    try:
        return {
            name: {
                **value,
                "address": int(value["address"], 16),
                "starknet_address": int(value["starknet_address"], 16),
            }
            for name, value in json.load(
                open(DEPLOYMENTS_DIR / "kakarot_deployments.json", "r")
            ).items()
        }
    except FileNotFoundError:
        return {}


def get_log_receipts(tx_receipt):
    if WEB3.is_connected():
        return tx_receipt.logs

    kakarot_address = _get_starknet_deployments()["kakarot"]["address"]
    kakarot_events = [
        event
        for event in tx_receipt.events
        if event.from_address == kakarot_address and event.keys[0] < 2**160
    ]
    return [
        LogReceipt(
            address=to_checksum_address(f"0x{event.keys[0]:040x}"),
            blockHash=bytes(),
            blockNumber=bytes(),
            data=bytes(event.data),
            logIndex=log_index,
            topic=bytes(),
            topics=[
                bytes.fromhex(
                    # event "keys" in cairo are event "topics" in EVM
                    # they're returned as list where consecutive values are indeed
                    # low, high, low, high, etc. of the Uint256 cairo representation
                    # of the bytes32 topics. This recomputes the original topic
                    f"{(event.keys[i] + 2**128 * event.keys[i + 1]):064x}"
                )
                # every kkrt evm event emission appends the emitting contract as the first value of the event key (as felt), we skip those here
                for i in range(1, len(event.keys), 2)
            ],
            transactionHash=bytes(),
            transactionIndex=0,
        )
        for log_index, event in enumerate(kakarot_events)
    ]


def _parse_events(cls: ContractEvents, tx_receipt):
    log_receipts = get_log_receipts(tx_receipt)

    return {
        event_abi.get("name"): _get_matching_logs_for_event(event_abi, log_receipts)
        for event_abi in cls._events
    }


def _get_matching_logs_for_event(event_abi, log_receipts) -> List[dict]:
    logs = []
    for log_receipt in log_receipts:
        try:
            event_data = get_event_data(WEB3.codec, event_abi, log_receipt)
            logs += [event_data["args"]]
        except (MismatchedABI, LogTopicError, InsufficientDataBytes):
            pass
    return logs


def _wrap_kakarot(fun: str, caller_eoa: Optional[Account] = None):
    """Wrap a contract function call with the Kakarot contract."""

    async def _wrapper(self, *args, **kwargs):
        abi = self.get_function_by_name(fun).abi
        gas_price = kwargs.pop("gas_price", DEFAULT_GAS_PRICE)
        gas_limit = kwargs.pop("gas_limit", TRANSACTION_GAS_LIMIT)
        value = kwargs.pop("value", 0)
        caller_eoa_ = kwargs.pop("caller_eoa", caller_eoa)
        max_fee = kwargs.pop("max_fee", None)
        calldata = self.get_function_by_name(fun)(
            *args, **kwargs
        )._encode_transaction_data()

        if abi["stateMutability"] in ["pure", "view"]:
            origin = (
                int(caller_eoa_.signer.public_key.to_address(), 16)
                if caller_eoa_
                else int(EVM_ADDRESS, 16)
            )
            payload = {
                "nonce": 0,
                "from": Web3.to_checksum_address(f"{origin:040x}"),
                "to": self.address,
                "gas_limit": gas_limit,
                "gas_price": gas_price,
                "value": value,
                "data": HexBytes(calldata),
                "access_list": [],
            }
            if WEB3.is_connected():
                result = WEB3.eth.call(payload)
            else:
                kakarot_contract = _get_starknet_contract("kakarot")
                payload["to"] = {"is_some": 1, "value": int(payload["to"], 16)}
                payload["data"] = list(payload["data"])
                payload["origin"] = int(payload["from"], 16)
                del payload["from"]
                result = await kakarot_contract.functions["eth_call"].call(**payload)
                if result.success == 0:
                    raise EvmTransactionError(bytes(result.return_data))
                result = result.return_data
            types = get_abi_output_types(abi)
            decoded = decode(types, bytes(result))
            normalized = map_abi_data(BASE_RETURN_NORMALIZERS, types, decoded)
            return normalized[0] if len(normalized) == 1 else normalized

        logger.info(f"⏳ Executing {fun} at address {self.address}")
        receipt, response, success, gas_used = await eth_send_transaction(
            to=self.address,
            value=value,
            gas=gas_limit,
            data=calldata,
            caller_eoa=caller_eoa_ if caller_eoa_ else None,
            max_fee=max_fee,
            gas_price=gas_price,
        )
        if success == 0:
            logger.error(f"❌ {self.address}.{fun} failed")
            raise EvmTransactionError(bytes(response))
        logger.info(f"✅ {self.address}.{fun}")
        return {
            "receipt": receipt,
            "response": response,
            "success": success,
            "gas_used": gas_used,
        }

    return _wrapper


async def _contract_exists(address: int) -> bool:
    try:
        await RPC_CLIENT.get_class_hash_at(address)
        return True
    except ClientError:
        return False


async def get_eoa(private_key=None, amount=0) -> Account:
    private_key = private_key or keys.PrivateKey(bytes.fromhex(EVM_PRIVATE_KEY[2:]))
    starknet_address = await deploy_and_fund_evm_address(
        private_key.public_key.to_checksum_address(), amount
    )

    return Account(
        address=starknet_address,
        client=RPC_CLIENT,
        chain=ChainId.starknet_chain_id,
        # This is somehow a hack because we put EVM private key into a
        # Stark signer KeyPair to have both a regular Starknet account
        # and the access to the private key
        key_pair=KeyPair(int(private_key), private_key.public_key),
    )


async def send_pre_eip155_transaction(
    evm_address: str,
    starknet_address: Union[int, str],
    signed_tx: bytes,
):
    rlp_decoded = rlp.decode(signed_tx)
    v, r, s = rlp_decoded[-3:]
    unsigned_tx_data = rlp_decoded[:-3]
    unsigned_encoded_tx = rlp.encode(unsigned_tx_data)
    msg_hash = int.from_bytes(keccak(unsigned_encoded_tx), "big")

    await _invoke_starknet(
        "kakarot", "set_authorized_pre_eip155_tx", int(evm_address, 16), msg_hash
    )

    if WEB3.is_connected():
        tx_hash = WEB3.eth.send_raw_transaction(signed_tx)
        receipt = WEB3.eth.wait_for_transaction_receipt(
            tx_hash, timeout=NETWORK["max_wait"], poll_latency=NETWORK["check_interval"]
        )
        return receipt, [], receipt.status, receipt.gasUsed

    sender_account = Account(
        address=starknet_address,
        client=RPC_CLIENT,
        chain=ChainId.starknet_chain_id,
        # Keypair not required for already signed txs
        key_pair=KeyPair(int(0x10), 0x20),
    )
    return await send_starknet_transaction(
        evm_account=sender_account,
        signature_r=int.from_bytes(r, "big"),
        signature_s=int.from_bytes(s, "big"),
        signature_v=int.from_bytes(v, "big"),
        packed_encoded_unsigned_tx=pack_calldata(unsigned_encoded_tx),
    )


async def eth_get_code(address: Union[int, str]):
    starknet_address = await get_starknet_address(address)
    return bytes(
        (
            await _call_starknet(
                "account_contract", "bytecode", address=starknet_address
            )
        ).bytecode
    )


async def eth_get_transaction_count(address: Union[int, str]):
    starknet_address = await get_starknet_address(address)
    return (
        await _call_starknet("account_contract", "get_nonce", address=starknet_address)
    ).nonce


async def eth_balance_of(address: Union[int, str]):
    starknet_address = await get_starknet_address(address)
    return await get_balance(starknet_address)


async def eth_send_transaction(
    to: Union[int, str],
    data: Union[str, bytes],
    gas: int = 21_000,
    value: Union[int, str] = 0,
    caller_eoa: Optional[Account] = None,
    max_fee: Optional[int] = None,
    gas_price=DEFAULT_GAS_PRICE,
):
    """Execute the data at the EVM contract to on Kakarot."""
    evm_account = caller_eoa or await get_eoa()
    if WEB3.is_connected():
        nonce = WEB3.eth.get_transaction_count(
            evm_account.signer.public_key.to_checksum_address()
        )
    else:
        nonce = (
            await (
                _get_starknet_contract("account_contract", address=evm_account.address)
                .functions["get_nonce"]
                .call()
            )
        ).nonce

    payload = {
        "type": 0x1,
        "chainId": NETWORK["chain_id"],
        "nonce": nonce,
        "gas": gas,
        "gasPrice": gas_price,
        "to": to_checksum_address(to) if to else None,
        "value": value,
        "data": data,
    }

    typed_transaction = TypedTransaction.from_dict(payload)

    evm_tx = EvmAccount.sign_transaction(
        typed_transaction.as_dict(),
        hex(evm_account.signer.private_key),
    )

    if WEB3.is_connected():
        tx_hash = WEB3.eth.send_raw_transaction(evm_tx.raw_transaction)
        receipt = WEB3.eth.wait_for_transaction_receipt(
            tx_hash, timeout=NETWORK["max_wait"], poll_latency=NETWORK["check_interval"]
        )
        return receipt, [], receipt.status, receipt.gasUsed

    encoded_unsigned_tx = rlp_encode_signed_data(typed_transaction.as_dict())
    packed_encoded_unsigned_tx = pack_calldata(bytes(encoded_unsigned_tx))
    return await send_starknet_transaction(
        evm_account,
        evm_tx.r,
        evm_tx.s,
        evm_tx.v,
        packed_encoded_unsigned_tx,
        max_fee,
    )


async def send_starknet_transaction(
    evm_account,
    signature_r: int,
    signature_s: int,
    signature_v: int,
    packed_encoded_unsigned_tx: List[int],
    max_fee: Optional[int] = None,
):
    relayer = next(NETWORK["relayers"])
    current_timestamp = (await RPC_CLIENT.get_block("latest")).timestamp
    outside_execution = {
        "caller": int.from_bytes(b"ANY_CALLER", "big"),
        "nonce": 0,  # not used in Kakarot
        "execute_after": current_timestamp - 60 * 60,
        "execute_before": current_timestamp + 60 * 60,
    }
    max_fee = _max_fee if max_fee in [None, 0] else max_fee
    response = (
        await _get_starknet_contract(
            "account_contract", address=evm_account.address, provider=relayer
        )
        .functions["execute_from_outside"]
        .invoke_v1(
            outside_execution=outside_execution,
            call_array=[
                {
                    "to": 0xDEAD,
                    "selector": 0xDEAD,
                    "data_offset": 0,
                    "data_len": len(packed_encoded_unsigned_tx),
                }
            ],
            calldata=list(packed_encoded_unsigned_tx),
            signature=[
                *int_to_uint256(signature_r),
                *int_to_uint256(signature_s),
                signature_v,
            ],
            max_fee=max_fee,
        )
    )

    await wait_for_transaction(tx_hash=response.hash)
    receipt = await RPC_CLIENT.get_transaction_receipt(response.hash)
    transaction_events = [
        event
        for event in receipt.events
        if event.from_address == evm_account.address
        and event.keys[0] == starknet_keccak(b"transaction_executed")
    ]
    if receipt.execution_status.name == "REVERTED":
        raise StarknetTransactionError(f"Starknet tx reverted: {receipt.revert_reason}")
    if len(transaction_events) != 1:
        raise ValueError("Cannot locate the single event giving the actual tx status")
    (
        response_len,
        *response,
        success,
        gas_used,
    ) = transaction_events[0].data

    if response_len != len(response):
        raise ValueError("Not able to parse event data")

    return receipt, response, success, gas_used


async def compute_starknet_address(address: Union[str, int]):
    """
    Compute the Starknet address of an EVM address.
    Warning: use get_starknet_address for getting the actual address of an account.
    """
    evm_address = int(address, 16) if isinstance(address, str) else address
    kakarot_contract = _get_starknet_contract("kakarot")
    return (
        await kakarot_contract.functions["compute_starknet_address"].call(evm_address)
    ).contract_address


async def get_starknet_address(address: Union[str, int]):
    """
    Get the registered Starknet address of an EVM address, or the one it would get
    if it was deployed right now with Kakarot.
    Warning: this may not be the same as compute_starknet_address if kakarot base uninitialized class hash has changed.
    """
    evm_address = int(address, 16) if isinstance(address, str) else address
    kakarot_contract = _get_starknet_contract("kakarot")
    return (
        await kakarot_contract.functions["get_starknet_address"].call(evm_address)
    ).starknet_address


async def deploy_and_fund_evm_address(evm_address: str, amount: float):
    """
    Deploy an EOA linked to the given EVM address and fund it with amount ETH.
    """
    starknet_address = await get_starknet_address(int(evm_address, 16))
    account_balance = await get_balance(evm_address)
    if account_balance < amount:
        await fund_address(evm_address, amount - account_balance)
    if not await _contract_exists(starknet_address):
        await _invoke_starknet(
            "kakarot",
            "deploy_externally_owned_account",
            int(evm_address, 16),
            account=next(NETWORK["relayers"]),
        )
    return starknet_address


async def fund_address(address: Union[str, int], amount: float):
    starknet_address = await get_starknet_address(address)
    logger.info(
        f"ℹ️  Funding EVM address {address} at Starknet address {hex(starknet_address)}"
    )
    await _fund_starknet_address(starknet_address, amount)


async def store_bytecode(bytecode: Union[str, bytes], **kwargs):
    """
    Deploy a contract account through Kakarot with given bytecode as finally
    stored bytecode.

    Note: Deploying directly a contract account and using `write_bytecode` would not
    produce an EVM contract registered in Kakarot and thus is not an option. We need
    to have Kakarot deploying EVM contrats.
    """
    bytecode = (
        bytecode
        if isinstance(bytecode, bytes)
        else bytes.fromhex(bytecode.replace("0x", ""))
    )

    # Defines variables for used opcodes to make it easier to write the mnemonic
    PUSH1 = "60"
    PUSH2 = "61"
    CODECOPY = "39"
    RETURN = "f3"
    # The deploy_bytecode is crafted such that:
    # - append at the end of the run bytecode the target bytecode
    # - load this chunk of code in memory using CODECOPY
    # - return this data in RETURN
    #
    # Bytecode usage
    # - CODECOPY(len, offset, destOffset): set memory such that memory[destOffset:destOffset + len] = code[offset:offset + len]
    # - RETURN(len, offset): return memory[offset:offset + len]
    deploy_bytecode = bytes.fromhex(
        f"""
    {PUSH2} {len(bytecode):04x}
    {PUSH1} 0e
    {PUSH1} 00
    {CODECOPY}
    {PUSH2} {len(bytecode):04x}
    {PUSH1} 00
    {RETURN}
    {bytecode.hex()}"""
    )
    _, response, success, _ = await eth_send_transaction(
        to=0, data=deploy_bytecode, **kwargs
    )
    assert success
    _, evm_address = response
    stored_bytecode = await eth_get_code(evm_address)
    assert stored_bytecode == bytecode
    return evm_address


async def deploy_with_presigned_tx(
    deployer_evm_address: str, signed_tx: bytes, amount=0.1, name=""
):
    deployer_starknet_address = await deploy_and_fund_evm_address(
        deployer_evm_address, amount
    )
    receipt, response, success, gas_used = await send_pre_eip155_transaction(
        deployer_evm_address, deployer_starknet_address, signed_tx
    )
    deployed_address = response[1]
    logger.info(f"✅ {name} Deployed at: 0x{deployed_address:040x}")
    deployed_starknet_address = await get_starknet_address(deployed_address)
    return {"address": deployed_address, "starknet_address": deployed_starknet_address}
