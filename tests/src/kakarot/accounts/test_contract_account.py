import random
from textwrap import wrap
from unittest.mock import call, patch

import pytest
from starkware.starknet.public.abi import (
    get_selector_from_name,
    get_storage_var_address,
)

from tests.utils.errors import cairo_error
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256


class TestContractAccount:
    @pytest.fixture(params=[0, 10, 100, 1000, 10000])
    def bytecode(self, request):
        random.seed(0)
        return random.randbytes(request.param)

    class TestInitialize:
        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        @SyscallHandler.patch("Account_kakarot_address", 0x1234)
        @SyscallHandler.patch("Account_evm_address", 0xABDE1)
        def test_should_store_given_addresses(self, cairo_run):
            cairo_run(
                "test__initialize__should_store_given_evm_address",
                implementation_class=0xC1A55,
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Ownable_owner"), value=0x1234
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_evm_address"), value=0xABDE1
            )

        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        @SyscallHandler.patch("Account_kakarot_address", 0x1234)
        @SyscallHandler.patch("Account_evm_address", 0xABDE1)
        def test_should_transfer_ownership_to_kakarot(self, cairo_run):
            cairo_run(
                "test__initialize__should_store_given_evm_address",
                implementation_class=0xC1A55,
            )
            SyscallHandler.mock_event.assert_any_call(
                keys=[get_selector_from_name("OwnershipTransferred")], data=[0, 0x1234]
            )

        @SyscallHandler.patch("Account_is_initialized", 1)
        @SyscallHandler.patch("Account_kakarot_address", 0x1234)
        @SyscallHandler.patch("Account_evm_address", 0xABDE1)
        def test_should_run_only_once(self, cairo_run):
            with cairo_error():
                cairo_run(
                    "test__initialize__should_store_given_evm_address",
                    implementation_class=0xC1A55,
                )

        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        @SyscallHandler.patch("Account_kakarot_address", 0x1234)
        @SyscallHandler.patch("Account_evm_address", 0xABDE1)
        def test_should_give_infinite_allowance_to_kakarot(self, cairo_run):
            cairo_run(
                "test__initialize__should_store_given_evm_address",
                implementation_class=0xC1A55,
            )
            SyscallHandler.mock_call.assert_any_call(
                contract_address=0xDEAD,
                function_selector=get_selector_from_name("approve"),
                calldata=[0x1234, *int_to_uint256(2**256 - 1)],
            )

    class TestGetEvmAddress:
        @SyscallHandler.patch("Account_evm_address", 0xABDE1)
        def test_should_return_stored_address(self, cairo_run):
            output = cairo_run("test__get_evm_address__should_return_stored_address")
            assert output == 0xABDE1

    class TestWriteBytecode:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error():
                cairo_run("test__write_bytecode", bytecode=[])

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_write_bytecode(self, cairo_run, bytecode):
            cairo_run("test__write_bytecode", bytecode=list(bytecode))
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_bytecode_len"),
                value=len(bytecode),
            )
            calls = [
                call(address=i, value=int(value, 16))
                for i, value in enumerate(wrap(bytecode.hex(), 2 * 31))
            ]
            SyscallHandler.mock_storage.assert_has_calls(calls)

    class TestBytecode:
        @pytest.fixture
        def storage(self, bytecode):
            chunks = wrap(bytecode.hex(), 2 * 31)

            def _storage(address):
                return (
                    int(chunks[address], 16)
                    if address != get_storage_var_address("Account_bytecode_len")
                    else len(bytecode)
                )

            return _storage

        def test_should_read_bytecode(self, cairo_run, bytecode, storage):
            with patch.object(
                SyscallHandler, "mock_storage", side_effect=storage
            ) as mock_storage:
                output_len, output = cairo_run("test__read_bytecode")
            chunk_counts, remainder = divmod(len(bytecode), 31)
            addresses = list(range(chunk_counts + (remainder > 0)))
            calls = [call(address=address) for address in addresses]
            mock_storage.assert_has_calls(calls)
            assert output[:output_len] == list(bytecode)
