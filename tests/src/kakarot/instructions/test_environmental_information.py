import random

import pytest
from Crypto.Hash import keccak

from tests.utils.syscall_handler import SyscallHandler

EXISTING_ACCOUNT = 0xABDE1
NON_EXISTING_ACCOUNT = 0xDEAD


@pytest.fixture(scope="module", params=[0, 32], ids=["no bytecode", "32 bytes"])
def bytecode(request):
    random.seed(0)
    return [random.randint(0, 255) for _ in range(request.param)]


@pytest.fixture(scope="module")
def bytecode_hash(bytecode):
    keccak_hash = keccak.new(digest_bits=256)
    keccak_hash.update(bytearray(bytecode))
    return int.from_bytes(keccak_hash.digest(), byteorder="big")


@pytest.fixture(
    scope="module",
    params=[EXISTING_ACCOUNT, NON_EXISTING_ACCOUNT],
    ids=["existing", "non existing"],
)
def address(request):
    return request.param


class TestEnvironmentalInformation:
    class TestAddress:
        def test_should_push_address(self, cairo_run):
            cairo_run("test__exec_address__should_push_address_to_stack")

    class TestExtCodeSize:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch(
            "IAccount.account_type", lambda addr, data: [int.from_bytes(b"CA", "big")]
        )
        @SyscallHandler.patch("IContractAccount.get_nonce", lambda addr, data: [1])
        @SyscallHandler.patch("evm_to_starknet_address", EXISTING_ACCOUNT, 0x1234)
        def test_extcodesize_should_push_code_size(self, cairo_run, bytecode, address):
            with SyscallHandler.patch(
                "IAccount.bytecode", lambda addr, data: [len(bytecode), *bytecode]
            ):
                output = cairo_run("test__exec_extcodesize", address=address)

            assert output[0] == (len(bytecode) if address == EXISTING_ACCOUNT else 0)
            assert output[1] == 0

    class TestExtCodeCopy:
        @pytest.mark.parametrize(
            "case",
            [
                {
                    "size": 31,
                    "offset": 0,
                    "dest_offset": 0,
                },
                {
                    "size": 33,
                    "offset": 0,
                    "dest_offset": 0,
                },
                {
                    "size": 1,
                    "offset": 32,
                    "dest_offset": 0,
                },
            ],
            ids=[
                "size_is_bytecodelen-1",
                "size_is_bytecodelen+1",
                "offset_is_bytecodelen",
            ],
        )
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch(
            "IAccount.account_type", lambda addr, data: [int.from_bytes(b"CA", "big")]
        )
        @SyscallHandler.patch("IContractAccount.get_nonce", lambda addr, data: [1])
        @SyscallHandler.patch("evm_to_starknet_address", EXISTING_ACCOUNT, 0x1234)
        def test_extcodecopy_should_copy_code(self, cairo_run, case, bytecode, address):
            size = case["size"]
            offset = case["offset"]
            dest_offset = case["dest_offset"]

            with SyscallHandler.patch(
                "IAccount.bytecode", lambda addr, data: [len(bytecode), *bytecode]
            ):
                output = cairo_run(
                    "test__exec_extcodecopy",
                    size=size,
                    offset=offset,
                    dest_offset=dest_offset,
                    address=address,
                )

            expected = (
                (bytecode + [0] * (offset + size))[offset : (offset + size)]
                if address == EXISTING_ACCOUNT
                else [0] * size
            )

            assert output == expected

    class TestGasPrice:
        def test_gasprice(self, cairo_run):
            cairo_run("test__exec_gasprice")

    class TestExtCodeHash:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch(
            "IAccount.account_type", lambda addr, data: [int.from_bytes(b"CA", "big")]
        )
        @SyscallHandler.patch("IContractAccount.get_nonce", lambda addr, data: [1])
        @SyscallHandler.patch("evm_to_starknet_address", EXISTING_ACCOUNT, 0x1234)
        def test_extcodehash__should_push_hash(
            self, cairo_run, bytecode, bytecode_hash, address
        ):
            with SyscallHandler.patch(
                "IAccount.bytecode", lambda addr, data: [len(bytecode), *bytecode]
            ):
                output = cairo_run("test__exec_extcodehash", address=address)

            assert output == (
                [bytecode_hash % (2**128), bytecode_hash >> 128]
                if address == EXISTING_ACCOUNT
                else [0, 0]
            )
