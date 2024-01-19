import time
from dataclasses import dataclass
from functools import wraps

from starkware.starknet.public.abi import get_selector_from_name


@dataclass
class SyscallHandler:
    """
    Mock class for execution of system calls in the StarkNet OS.

    See starkware.starknet.common.syscalls.cairo for the list of system calls.
    """

    block_number: int = 0xABDE1
    block_timestamp: int = int(time.time())
    contract_address: int = 0xABDE1
    patches = {}

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

    def storage_read(self, segments, syscall_ptr):
        """
        Return a constant value for the storage read system call.

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
        segments.write_arg(syscall_ptr + 2, [0x1234])

    def call_contract(self, segments, syscall_ptr):
        """
        Return a constant List[int] as a random value for the call contract system call.

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
        retdata = self.patches.get(function_selector)(contract_address, calldata)
        retdata_segment = segments.add()
        segments.write_arg(retdata_segment, retdata)
        segments.write_arg(syscall_ptr + 5, [len(retdata), retdata_segment])

    @classmethod
    def patch(cls, target: str, value: callable):
        """
        Patch the target with the value.

        :param target: The target to patch, e.g. "IERC20.balanceOf". Note the only the last part of
            the target is used, but the whole name is kept for readability.
        :param value: The value to patch with, a callable that will be called with the contract
            address and the calldata, and should return the retdata as a List[int].
        """

        def decorator(test_fun):
            @wraps(test_fun)
            def decorated(self, *args, **kwargs):
                selector = get_selector_from_name(target.split(".")[-1])
                cls.patches[selector] = value
                result = test_fun(self, *args, **kwargs)
                del cls.patches[selector]
                return result

            return decorated

        return decorator
