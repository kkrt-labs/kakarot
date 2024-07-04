import time
from collections import OrderedDict
from contextlib import contextmanager
from dataclasses import dataclass
from hashlib import sha256
from typing import Optional, Union
from unittest import mock

import ecdsa
from eth_utils import keccak
from ethereum.base_types import U256
from ethereum.crypto.elliptic_curve import SECP256K1N, secp256k1_recover
from ethereum.crypto.hash import keccak256
from starkware.starknet.public.abi import (
    get_selector_from_name,
    get_storage_var_address,
)

from tests.utils.constants import ACCOUNT_CLASS_IMPLEMENTATION, CHAIN_ID
from tests.utils.uint256 import int_to_uint256, uint256_to_int


def cairo_keccak(class_hash, calldata):
    return int_to_uint256(
        int.from_bytes(
            keccak(
                b"".join(
                    [num.to_bytes(8, "little") for num in calldata[1:-2]]
                    + [calldata[-2].to_bytes(calldata[-1], "little")]
                )
            ),
            "big",
        )
    )


def cairo_recover_eth_address(class_hash, calldata):
    """
    Convert the input calldata from Cairo's `recover_eth_address` into a signature and a message hash,
    and then recover the Ethereum address from the signature.
    """
    msg_hash = b"".join([num.to_bytes(16, "big") for num in reversed(calldata[0:2])])
    r = U256(uint256_to_int(calldata[2], calldata[3]))
    s = U256(uint256_to_int(calldata[4], calldata[5]))
    y_parity = U256(calldata[6])

    if 0 >= r or r >= SECP256K1N:
        return [0, 0]
    if 0 >= s or s >= SECP256K1N:
        return [0, 0]
    try:
        public_key = secp256k1_recover(r, s, y_parity, msg_hash)
    except Exception:
        return [0, 0]  # return [is_some: 0, address: 0]
    return [
        1,
        int.from_bytes(keccak256(public_key)[12:32], "big"),
    ]  # return [is_some: 1, address: int]


def cairo_verify_signature_secp256r1(class_hash, calldata):
    """
    Convert the input calldata from Cairo's `verify_signature_secp256r1` into a message hash,
    signature and public key, and verify the signature on the secp256r1 curve.
    """

    msg_hash = uint256_to_int(calldata[0], calldata[1])
    r = uint256_to_int(calldata[2], calldata[3])
    s = uint256_to_int(calldata[4], calldata[5])
    x = uint256_to_int(calldata[6], calldata[7])
    y = uint256_to_int(calldata[8], calldata[9])

    rawPublicKey = x.to_bytes(32, "big") + y.to_bytes(32, "big")
    verifyingKey = ecdsa.VerifyingKey.from_string(
        rawPublicKey, curve=ecdsa.NIST256p, hashfunc=sha256
    )
    public_key = verifyingKey.pubkey
    signature = ecdsa.ecdsa.Signature(r, s)
    is_valid = public_key.verifies(msg_hash, signature)
    return [is_valid]


def parse_state(state):
    """
    Parse a serialized state as a dict of string, mainly converting hex strings to
    integers and computing the corresponding kakarot storage key from the EVM one.

    Input state be like:
        {
            '0x1000000000000000000000000000000000000000': {
                'balance': '0x00',
                'code': '0x6000600060006000346000355af1600055600160015500',
                'nonce': '0x00',
                'storage': {}
            },
            '0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b': {
                'balance': '0xffffffffffffffffffffffffffffffff',
                'code': '0x',
                'nonce': '0x00',
                'storage': {},
            }
        }
    """
    return {
        (int(address, 16) if not isinstance(address, int) else address): {
            "balance": (
                int(account["balance"], 16)
                if not isinstance(account["balance"], int)
                else account["balance"]
            ),
            "code": (
                list(bytes.fromhex(account["code"].replace("0x", "")))
                if isinstance(account["code"], str)
                else account["code"]
            ),
            "nonce": (
                int(account["nonce"], 16)
                if not isinstance(account["nonce"], int)
                else account["nonce"]
            ),
            "storage": {
                (
                    get_storage_var_address(
                        "Account_storage", *int_to_uint256(int(key, 16))
                    )
                    if not isinstance(key, int)
                    else key
                ): (int(value, 16) if not isinstance(value, int) else value)
                for key, value in account["storage"].items()
            },
        }
        for address, account in state.items()
    }


@dataclass
class SyscallHandler:
    """
    Mock class for execution of system calls in the StarkNet OS.

    See starkware.starknet.common.syscalls.cairo for the list of system calls.
    """

    block_number: int = 0xABDE1
    block_timestamp: int = int(time.time())
    tx_info = OrderedDict(
        {
            "version": 1,
            "account_contract_address": 0xABDE1,
            "max_fee": int(1e17),
            # Signature len will be set later based on the signature.
            "signature_len": None,
            "signature": [],
            "transaction_hash": 0xABDE1,
            "chain_id": CHAIN_ID,
            "nonce": 1,
        }
    )
    contract_address: int = 0xABDE1
    caller_address: int = 0xABDE1
    class_hash: int = 0xC1A55
    mock_call = mock.MagicMock()
    mock_library_call = mock.MagicMock()
    mock_storage = mock.MagicMock()
    mock_event = mock.MagicMock()
    mock_replace_class = mock.MagicMock()
    mock_send_message_to_l1 = mock.MagicMock()
    mock_deploy = mock.MagicMock()

    # Patch the keccak library call to return the keccak of the input data.
    # We need to reconstruct the raw bytes from the Cairo-style keccak calldata.
    patches = {
        get_selector_from_name("keccak"): cairo_keccak,
        get_selector_from_name("recover_eth_address"): cairo_recover_eth_address,
        get_selector_from_name(
            "verify_signature_secp256r1"
        ): cairo_verify_signature_secp256r1,
        get_selector_from_name("get_implementation"): lambda addr, data: [
            ACCOUNT_CLASS_IMPLEMENTATION
        ],
        get_selector_from_name("set_implementation"): lambda addr, data: [],
    }

    def __post_init__(self):
        self.patches[get_selector_from_name("execute_starknet_call")] = (
            lambda addr, data: self.execute_starknet_call(addr, data)
        )

    def execute_starknet_call(self, account_address, calldata):
        contract_address = calldata[0]
        function_selector = calldata[1]
        calldata = calldata[2:]

        if function_selector not in self.patches:
            raise ValueError(
                f"Function selector 0x{function_selector:x} not found in patches."
            )
        self.mock_call(
            contract_address=contract_address,
            function_selector=function_selector,
            calldata=calldata,
        )
        inner_retdata = self.patches.get(function_selector)(contract_address, calldata)
        return [len(inner_retdata), *inner_retdata, 1]

    def get_contract_address(self, segments, syscall_ptr):
        """
        Return a constant value for the get contract address system call.

        Syscall structure is:

            const GET_CONTRACT_ADDRESS_SELECTOR = 'GetContractAddress';

            struct GetContractAddressRequest {
                selector: felt,
            }

            struct GetContractAddressResponse {
                contract_address: felt,
            }

            struct GetContractAddress {
                request: GetContractAddressRequest,
                response: GetContractAddressResponse,
            }
        """
        segments.write_arg(syscall_ptr + 1, [self.contract_address])

    def get_caller_address(self, segments, syscall_ptr):
        """
        Return a constant value for the get caller address system call.

        Syscall structure is:

            struct GetCallerAddressRequest {
                selector: felt,
            }

            struct GetCallerAddressResponse {
                caller_address: felt,
            }

            struct GetCallerAddress {
                request: GetCallerAddressRequest,
                response: GetCallerAddressResponse,
            }
        """
        segments.write_arg(syscall_ptr + 1, [self.caller_address])

    @classmethod
    def get_block_number(cls, segments, syscall_ptr):
        """
        Return a constant value for the get block number system call.

        Syscall structure is:

            struct GetBlockNumberRequest {
                selector: felt,
            }

            struct GetBlockNumberResponse {
                block_number: felt,
            }

            struct GetBlockNumber {
                request: GetBlockNumberRequest,
                response: GetBlockNumberResponse,
            }
        """
        segments.write_arg(syscall_ptr + 1, [cls.block_number])

    @classmethod
    def get_block_timestamp(cls, segments, syscall_ptr):
        """
        Return a constant value for the get block timestamp system call.

        Syscall structure is:

            struct GetBlockTimestampRequest {
                selector: felt,
            }

            struct GetBlockTimestampResponse {
                timestamp: felt,
            }

            struct GetBlockTimestamp {
                request: GetBlockTimestampRequest,
                response: GetBlockTimestampResponse,
            }
        """
        segments.write_arg(syscall_ptr + 1, [cls.block_timestamp])

    def get_tx_info(self, segments, syscall_ptr):
        """
        Return a constant value for the get tx info system call.

        Syscall structure is:
            struct GetTxInfoRequest {
                selector: felt,
            }

            struct GetTxInfoResponse {
                tx_info: TxInfo*,
            }

            struct GetTxInfo {
                request: GetTxInfoRequest,
                response: GetTxInfoResponse,
            }
        """
        signature_segment = segments.add()
        segments.write_arg(signature_segment, self.tx_info["signature"])
        tx_info = {
            **self.tx_info,
            "signature_len": len(self.tx_info["signature"]),
            "signature": signature_segment,
        }
        tx_info_segment = segments.add()
        segments.write_arg(tx_info_segment, tx_info.values())
        segments.write_arg(syscall_ptr + 1, [tx_info_segment])

    def storage_read(self, segments, syscall_ptr):
        """
        Return a constant value for the storage read system call.
        We use the patches dict to store the storage values; returned value is 0 if the address is not found as in Starknet.
        Value can also be set by patching the underling mock_storage object.

        Syscall structure is:

            struct StorageReadRequest {
                selector: felt,
                address: felt,
            }

            struct StorageReadResponse {
                value: felt,
            }

            struct StorageRead {
                request: StorageReadRequest,
                response: StorageReadResponse,
            }
        """
        address = segments.memory[syscall_ptr + 1]
        mock = self.mock_storage(address=address)
        patched = self.patches.get(address)
        value = (
            patched if patched is not None else (mock if isinstance(mock, int) else 0)
        )
        segments.write_arg(syscall_ptr + 2, [value])

    def storage_write(self, segments, syscall_ptr):
        """
        Record the call in the internal mock object.

        Syscall structure is:

            struct StorageWrite {
                selector: felt,
                address: felt,
                value: felt,
            }
        """
        self.mock_storage(
            address=segments.memory[syscall_ptr + 1],
            value=segments.memory[syscall_ptr + 2],
        )

    def replace_class(self, segments, syscall_ptr):
        """
        Record the replaced class hash in the internal mock object and update the class_hash attribute.

        Syscall structure is:

            struct ReplaceClass {
                selector: felt,
                class_hash: felt,
            }
        """
        class_hash = segments.memory[syscall_ptr + 1]
        self.mock_replace_class(
            class_hash=class_hash,
        )

    def emit_event(self, segments, syscall_ptr):
        """
        Record the call in the internal mock object.

        Syscall structure is:

            struct EmitEvent {
                selector: felt,
                keys_len: felt,
                keys: felt*,
                data_len: felt,
                data: felt*,
            }
        """
        keys_len = segments.memory[syscall_ptr + 1]
        keys_ptr = segments.memory[syscall_ptr + 2]
        keys = [segments.memory[keys_ptr + i] for i in range(keys_len)]
        data_len = segments.memory[syscall_ptr + 3]
        data_ptr = segments.memory[syscall_ptr + 4]
        data = [segments.memory[data_ptr + i] for i in range(data_len)]
        self.mock_event(keys=keys, data=data)

    def call_contract(self, segments, syscall_ptr):
        """
        Call the registered mock function for the given selector.
        Raise ValueError if the selector is not found in the patches dict.

        Syscall structure is:

            struct CallContractRequest {
                selector: felt,
                contract_address: felt,
                function_selector: felt,
                calldata_size: felt,
                calldata: felt*,
            }

            struct CallContractResponse {
                retdata_size: felt,
                retdata: felt*,
            }

            struct CallContract {
                request: CallContractRequest,
                response: CallContractResponse,
            }
        """
        function_selector = segments.memory[syscall_ptr + 2]
        if function_selector not in self.patches:
            raise ValueError(
                f"Function selector 0x{function_selector:x} not found in patches."
            )

        contract_address = segments.memory[syscall_ptr + 1]
        calldata_ptr = segments.memory[syscall_ptr + 4]
        calldata = [
            segments.memory[calldata_ptr + i]
            for i in range(segments.memory[syscall_ptr + 3])
        ]
        self.mock_call(
            contract_address=contract_address,
            function_selector=function_selector,
            calldata=calldata,
        )
        retdata = self.patches.get(function_selector)(contract_address, calldata)
        retdata_segment = segments.add()
        segments.write_arg(retdata_segment, retdata)
        segments.write_arg(syscall_ptr + 5, [len(retdata), retdata_segment])

    def library_call(self, segments, syscall_ptr):
        """
        Call the registered mock function for the given selector.
        Raise ValueError if the selector is not found in the patches dict.

        Syscall structure is:
            struct LibraryCallRequest {
                selector: felt,
                class_hash: felt,
                function_selector: felt,
                calldata_size: felt,
                calldata: felt*,
            }

            struct LibraryCall {
                request: LibraryCallRequest,
                response: CallContractResponse,
            }
        """
        function_selector = segments.memory[syscall_ptr + 2]
        if function_selector not in self.patches:
            raise ValueError(
                f"Function selector 0x{function_selector:x} not found in patches."
            )

        class_hash = segments.memory[syscall_ptr + 1]
        calldata_ptr = segments.memory[syscall_ptr + 4]
        calldata = [
            segments.memory[calldata_ptr + i]
            for i in range(segments.memory[syscall_ptr + 3])
        ]
        self.mock_library_call(
            class_hash=class_hash,
            function_selector=function_selector,
            calldata=calldata,
        )
        retdata = self.patches.get(function_selector)(class_hash, calldata)
        retdata_segment = segments.add()
        segments.write_arg(retdata_segment, retdata)
        segments.write_arg(syscall_ptr + 5, [len(retdata), retdata_segment])

    def send_message_to_l1(self, segments, syscall_ptr):
        """
        Record the send_message call in the internal mock object.

        Syscall structure is:
            struct SendMessageToL1SysCall {
                selector: felt,
                to_address: felt,
                payload_size: felt,
                payload_ptr: felt*,
            }
        """
        to_address = segments.memory[syscall_ptr + 1]
        payload_size = segments.memory[syscall_ptr + 2]
        payload_ptr = segments.memory[syscall_ptr + 3]
        payload = [segments.memory[payload_ptr + i] for i in range(payload_size)]
        self.mock_send_message_to_l1(to_address=to_address, payload=payload)

    def deploy(self, segments, syscall_ptr):
        """
        Record the deploy call in the internal mock object.

        Syscall structure is:
            struct DeployRequest {
                selector: felt,
                class_hash: felt,
                contract_address_salt: felt,
                constructor_calldata_size: felt,
                constructor_calldata: felt*,
                deploy_from_zero: felt,
            }

            struct DeployResponse {
                contract_address: felt,
                constructor_retdata_size: felt,
                constructor_retdata: felt*,
            }

        """
        class_hash = segments.memory[syscall_ptr + 1]
        contract_address_salt = segments.memory[syscall_ptr + 2]
        constructor_calldata_size = segments.memory[syscall_ptr + 3]
        constructor_calldata_ptr = segments.memory[syscall_ptr + 4]
        constructor_calldata = [
            segments.memory[constructor_calldata_ptr + i]
            for i in range(constructor_calldata_size)
        ]
        deploy_from_zero = segments.memory[syscall_ptr + 5]
        self.mock_deploy(
            class_hash=class_hash,
            contract_address_salt=contract_address_salt,
            constructor_calldata=constructor_calldata,
            deploy_from_zero=deploy_from_zero,
        )

        retdata = self.patches.get("deploy")(class_hash, constructor_calldata)
        retdata_segment = segments.add()
        segments.write_arg(retdata_segment, retdata)
        segments.write_arg(syscall_ptr + 6, [len(retdata), retdata_segment])

    @classmethod
    @contextmanager
    def patch_deploy(cls, value: callable):
        """
        Patch the deploy syscall with the value.

        :param value: The value to patch with, a callable that will be called with the class hash,
            the contract address salt, the constructor calldata and the deploy from zero flag.
        """
        cls.patches["deploy"] = value
        yield
        del cls.patches["deploy"]

    @classmethod
    @contextmanager
    def patch(
        cls,
        target: Union[int, str],
        *args,
        value: Optional[Union[callable, int]] = None,
    ):
        """
        Patch the target with the value.

        :param target: The target to patch, e.g. "IERC20.balanceOf" or "Kakarot_evm_to_starknet_address".
            Note that when patching a contract call, only the last part of the target is used.
        :param args: Additional arguments to pass to the target (when patching a storage var, see get_storage_var_address signature).
        :param value: The value to patch with, a callable that will be called with the contract
            address and the calldata, and should return the retdata as a List[int].
        """

        if isinstance(target, str):
            selector_if_call = get_selector_from_name(
                target.split(".")[-1].replace("library_call_", "")
            )
        else:
            selector_if_call = target

        if value is None:
            args = list(args)
            value = args.pop()
        cls.patches[selector_if_call] = value
        try:
            if isinstance(target, str):
                selector_if_storage = get_storage_var_address(target, *args)
            else:
                selector_if_storage = target
            cls.patches[selector_if_storage] = value
        except AssertionError:
            pass

        yield

        del cls.patches[selector_if_call]
        if "selector_if_storage" in globals():
            del cls.patches[selector_if_storage]

    @classmethod
    @contextmanager
    def patch_state(cls, state: dict):
        """
        Patch sycalls to match a given EVM state.

        Actual corresponding Starknet address are unknown but it doesn't matter since the
        Kakarot_evm_to_starknet_address storage is also patched.

        :param state: the state to patch with, an output dictionary of parse_state
        """
        patched_before = set(cls.patches.keys())

        def _balance_of(erc20_address, calldata):
            return int_to_uint256(state.get(calldata[0], {}).get("balance", 0))

        balance_selector = get_selector_from_name("balanceOf")
        cls.patches[balance_selector] = _balance_of

        def _bytecode(contract_address, calldata):
            code = state.get(contract_address, {}).get("code", [])
            return [len(code), *code]

        bytecode_selector = get_selector_from_name("bytecode")
        cls.patches[bytecode_selector] = _bytecode

        def _bytecode_len(contract_address, calldata):
            code = state.get(contract_address, {}).get("code", [])
            return [len(code)]

        bytecode_len_selector = get_selector_from_name("bytecode_len")
        cls.patches[bytecode_len_selector] = _bytecode_len

        def _get_nonce(contract_address, calldata):
            return [state.get(contract_address, {}).get("nonce", 0)]

        nonce_selector = get_selector_from_name("get_nonce")
        cls.patches[nonce_selector] = _get_nonce

        def _storage(contract_address, calldata):
            return int_to_uint256(
                state.get(contract_address, {}).get("storage", {}).get(calldata[0], 0)
            )

        storage_selector = get_selector_from_name("storage")
        cls.patches[storage_selector] = _storage

        # Register accounts
        for address in state.keys():
            address_selector = get_storage_var_address(
                "Kakarot_evm_to_starknet_address", address
            )
            cls.patches[address_selector] = address

        yield

        patched = set(cls.patches.keys())
        for selector in patched - patched_before:
            del cls.patches[selector]
