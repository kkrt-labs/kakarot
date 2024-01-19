import time

from starkware.starknet.public.abi import get_selector_from_name


class MockSyscallHandler:
    """
    Mock class for execution of system calls in the StarkNet OS.

    See starkware.starknet.common.syscalls.cairo for the list of system calls.
    """

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
        segments.write_arg(syscall_ptr + 1, [0xABDE1])

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
        if function_selector == get_selector_from_name("balanceOf"):
            retdata = [2, 0]
        elif function_selector == get_selector_from_name("account_type"):
            retdata = [int.from_bytes(b"EOA", "big")]
        retdata_segment = segments.add()
        segments.write_arg(retdata_segment, retdata)
        segments.write_arg(syscall_ptr + 5, [len(retdata), retdata_segment])

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
        segments.write_arg(syscall_ptr + 1, [0xABDE1])

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
        segments.write_arg(syscall_ptr + 1, [int(time.time())])
