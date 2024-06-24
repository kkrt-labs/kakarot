import functools
import json
import logging
from pathlib import Path
from types import MethodType
from typing import List, Optional, Union, cast

from eth_abi import decode
from eth_abi.exceptions import InsufficientDataBytes
from eth_account import Account as EvmAccount
from eth_account.typed_transactions import TypedTransaction
from eth_keys import keys
from eth_utils.address import to_checksum_address
from hexbytes import HexBytes
from starknet_py.net.account.account import Account
from starknet_py.net.client_errors import ClientError
from starknet_py.net.client_models import Call
from starknet_py.net.models.transaction import InvokeV1
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
    EVM_ADDRESS,
    EVM_PRIVATE_KEY,
    NETWORK,
    RPC_CLIENT,
    WEB3,
    ChainId,
)
from kakarot_scripts.utils.starknet import call as _call_starknet
from kakarot_scripts.utils.starknet import fund_address as _fund_starknet_address
from kakarot_scripts.utils.starknet import get_balance
from kakarot_scripts.utils.starknet import get_contract as _get_starknet_contract
from kakarot_scripts.utils.starknet import get_deployments
from kakarot_scripts.utils.starknet import invoke as _invoke_starknet
from kakarot_scripts.utils.starknet import wait_for_transaction
from tests.utils.constants import TRANSACTION_GAS_LIMIT
from tests.utils.helpers import pack_calldata, rlp_encode_signed_data
from tests.utils.uint256 import int_to_uint256

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class EvmTransactionError(Exception):
    pass


@functools.lru_cache()
def get_solidity_artifacts(
    contract_app: str,
    contract_name: str,
) -> Web3Contract:
    import toml

    try:
        foundry_file = toml.loads(
            (Path(__file__).parents[2] / "foundry.toml").read_text()
        )
    except (NameError, FileNotFoundError):
        foundry_file = toml.loads(Path("foundry.toml").read_text())

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
            (Path(foundry_file["profile"]["default"]["src"]) / contract_app).glob(
                f"**/{contract_name}.sol"
            )
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
    return {
        "bytecode": target_compilation_output["bytecode"]["object"],
        "bytecode_runtime": target_compilation_output["deployedBytecode"]["object"],
        "abi": target_compilation_output["abi"],
    }


@functools.lru_cache()
def get_vyper_artifacts(
    contract_app: str,
    contract_name: str,
) -> Web3Contract:
    from vyper.cli.vyper_compile import compile_files

    target_contract = (
        Path("vyper_contracts") / "src" / contract_app / f"{contract_name}.vy"
    )

    if not target_contract.is_file():
        raise ValueError("Cannot locate contract in app")

    return compile_files([target_contract], ["bytecode", "bytecode_runtime", "abi"])[
        target_contract
    ]


def get_contract(
    contract_app: str,
    contract_name: str,
    address=None,
    caller_eoa: Optional[Account] = None,
) -> Web3Contract:

    try:
        artifacts = get_solidity_artifacts(contract_app, contract_name)
    except ValueError:
        artifacts = get_vyper_artifacts(contract_app, contract_name)

    contract = cast(
        Web3Contract,
        WEB3.eth.contract(
            address=to_checksum_address(address) if address is not None else address,
            abi=artifacts["abi"],
            bytecode=artifacts["bytecode"],
        ),
    )
    contract.bytecode_runtime = HexBytes(artifacts["bytecode_runtime"])

    try:
        for fun in contract.functions:
            setattr(contract, fun, MethodType(_wrap_kakarot(fun, caller_eoa), contract))
    except NoABIFunctionsFound:
        pass
    contract.events.parse_events = MethodType(_parse_events, contract.events)
    return contract


async def deploy(
    contract_app: str, contract_name: str, *args, **kwargs
) -> Web3Contract:
    logger.info(f"⏳ Deploying {contract_name}")
    caller_eoa = kwargs.pop("caller_eoa", None)
    contract = get_contract(contract_app, contract_name, caller_eoa=caller_eoa)
    max_fee = kwargs.pop("max_fee", None)
    value = kwargs.pop("value", 0)
    receipt, response, success, _ = await eth_send_transaction(
        to=0,
        gas=int(TRANSACTION_GAS_LIMIT),
        data=contract.constructor(*args, **kwargs).data_in_transaction,
        caller_eoa=caller_eoa,
        max_fee=max_fee,
        value=value,
    )
    if success == 0:
        raise EvmTransactionError(bytes(response))

    if WEB3.is_connected():
        evm_address = int(receipt.contractAddress or receipt.to, 16)
        starknet_address = (
            await _call_starknet("kakarot", "compute_starknet_address", evm_address)
        ).contract_address
    else:
        starknet_address, evm_address = response
    contract.address = Web3.to_checksum_address(f"0x{evm_address:040x}")
    contract.starknet_address = starknet_address
    logger.info(f"✅ {contract_name} deployed at address {contract.address}")

    return contract


def get_log_receipts(tx_receipt):
    if WEB3.is_connected():
        return tx_receipt.logs

    kakarot_address = get_deployments()["kakarot"]["address"]
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
        logger.info(f"ℹ️  Contract at address {hex(address)} already exists")
        return True
    except ClientError:
        return False


async def get_eoa(private_key=None, amount=10) -> Account:
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


async def eth_send_transaction(
    to: Union[int, str],
    data: Union[str, bytes],
    gas: int = 21_000,
    value: Union[int, str] = 0,
    caller_eoa: Optional[Account] = None,
    max_fee: Optional[int] = None,
):
    """Execute the data at the EVM contract to on Kakarot."""
    evm_account = caller_eoa or await get_eoa()
    if WEB3.is_connected():
        nonce = WEB3.eth.get_transaction_count(
            evm_account.signer.public_key.to_checksum_address()
        )
    else:
        nonce = await evm_account.get_nonce()

    payload = {
        "type": 0x2,
        "chainId": NETWORK["chain_id"],
        "nonce": nonce,
        "gas": gas,
        "maxPriorityFeePerGas": 1,
        "maxFeePerGas": DEFAULT_GAS_PRICE,
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

    prepared_invoke = await evm_account._prepare_invoke(
        calls=[
            Call(
                to_addr=0xDEAD,  # unused in current EOA implementation
                selector=0xDEAD,  # unused in current EOA implementation
                calldata=packed_encoded_unsigned_tx,
            )
        ],
        max_fee=int(5e17) if max_fee is None else max_fee,
    )
    # We need to reconstruct the prepared_invoke with the new signature
    # And Invoke.signature is Frozen
    prepared_invoke = InvokeV1(
        version=prepared_invoke.version,
        max_fee=prepared_invoke.max_fee,
        signature=[*int_to_uint256(evm_tx.r), *int_to_uint256(evm_tx.s), evm_tx.v],
        nonce=prepared_invoke.nonce,
        sender_address=prepared_invoke.sender_address,
        calldata=prepared_invoke.calldata,
    )

    response = await evm_account.client.send_transaction(prepared_invoke)

    await wait_for_transaction(tx_hash=response.transaction_hash)
    receipt = await RPC_CLIENT.get_transaction_receipt(response.transaction_hash)
    transaction_events = [
        event
        for event in receipt.events
        if event.from_address == evm_account.address
        and event.keys[0] == starknet_keccak(b"transaction_executed")
    ]
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
    evm_address = int(address, 16) if isinstance(address, str) else address
    kakarot_contract = _get_starknet_contract("kakarot")
    return (
        await kakarot_contract.functions["compute_starknet_address"].call(evm_address)
    ).contract_address


async def deploy_and_fund_evm_address(evm_address: str, amount: float):
    """
    Deploy an EOA linked to the given EVM address and fund it with amount ETH.
    """
    starknet_address = (
        await _call_starknet(
            "kakarot", "compute_starknet_address", int(evm_address, 16)
        )
    ).contract_address

    account_balance = await get_balance(evm_address)
    await fund_address(evm_address, amount - account_balance)
    if not await _contract_exists(starknet_address):
        await _invoke_starknet(
            "kakarot", "deploy_externally_owned_account", int(evm_address, 16)
        )
    return starknet_address


async def fund_address(address: Union[str, int], amount: float):
    starknet_address = await compute_starknet_address(address)
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


async def eth_get_code(address: Union[int, str]):
    starknet_address = await compute_starknet_address(address)
    return bytes(
        (
            await _call_starknet(
                "account_contract", "bytecode", address=starknet_address
            )
        ).bytecode
    )
