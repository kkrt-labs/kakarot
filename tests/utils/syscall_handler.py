import time
from collections import OrderedDict
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Optional, Union
from unittest import mock

from starkware.starknet.public.abi import (
    get_selector_from_name,
    get_storage_var_address,
)

from tests.utils.constants import CHAIN_ID


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
    patches = {}
    mock_call = mock.MagicMock()
    mock_storage = mock.MagicMock()
    mock_event = mock.MagicMock()

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

    def get_block_number(self, segments, syscall_ptr):
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
        segments.write_arg(syscall_ptr + 1, [self.block_number])

    def get_block_timestamp(self, segments, syscall_ptr):
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
        segments.write_arg(syscall_ptr + 1, [self.block_timestamp])

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
        value = self.patches.get(address, 0)
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

    @classmethod
    @contextmanager
    def patch(cls, target: str, *args, value: Optional[Union[callable, int]] = None):
        """
        Patch the target with the value.

        :param target: The target to patch, e.g. "IERC20.balanceOf" or "evm_to_starknet_address".
            Note that when patching a contract call, only the last part of the target is used.
        :param args: Additional arguments to pass to the target (when patching a storage var, see get_storage_var_address signature).
        :param value: The value to patch with, a callable that will be called with the contract
            address and the calldata, and should return the retdata as a List[int].
        """
        selector_if_call = get_selector_from_name(target.split(".")[-1])
        if value is None:
            args = list(args)
            value = args.pop()
        cls.patches[selector_if_call] = value
        try:
            selector_if_storage = get_storage_var_address(target, *args)
            cls.patches[selector_if_storage] = value
        except AssertionError:
            pass

        yield

        del cls.patches[selector_if_call]
        if "selector_if_storage" in globals():
            del cls.patches[selector_if_storage]
