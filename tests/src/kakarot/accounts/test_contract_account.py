from unittest.mock import call

import pytest
from starkware.starknet.public.abi import (
    get_selector_from_name,
    get_storage_var_address,
)

from scripts.utils.kakarot import get_contract
from tests.utils.errors import cairo_error
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256


class TestContractAccount:
    class TestInitialize:
        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        def test_should_store_given_addresses(self, cairo_run):
            cairo_run(
                "test__initialize__should_store_given_evm_address",
                kakarot_address=0x1234,
                evm_address=0xABDE1,
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Ownable_owner"), value=0x1234
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("evm_address"), value=0xABDE1
            )

        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        def test_should_transfer_ownership_to_kakarot(self, cairo_run):
            cairo_run(
                "test__initialize__should_store_given_evm_address",
                kakarot_address=0x1234,
                evm_address=0xABDE1,
            )
            SyscallHandler.mock_event.assert_any_call(
                keys=[get_selector_from_name("OwnershipTransferred")], data=[0, 0x1234]
            )

        @SyscallHandler.patch("is_initialized_", 1)
        def test_should_run_only_once(self, cairo_run):
            with cairo_error():
                cairo_run(
                    "test__initialize__should_store_given_evm_address",
                    kakarot_address=0x1234,
                    evm_address=0xABDE1,
                )

        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        def test_should_give_infinite_allowance_to_kakarot(self, cairo_run):
            cairo_run(
                "test__initialize__should_store_given_evm_address",
                kakarot_address=0x1234,
                evm_address=0xABDE1,
            )
            SyscallHandler.mock_call.assert_any_call(
                contract_address=0xDEAD,
                function_selector=get_selector_from_name("approve"),
                calldata=[0x1234, *int_to_uint256(2**256 - 1)],
            )

    class TestGetEvmAddress:
        @SyscallHandler.patch("evm_address", 0xABDE1)
        def test_should_return_stored_address(self, cairo_run):
            output = cairo_run("test__get_evm_address__should_return_stored_address")
            assert output == [0xABDE1]

    class TestWriteBytecode:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error():
                cairo_run("test__write_bytecode", bytecode=[])

        @pytest.mark.parametrize(
            "bytecode",
            [
                list(range(10)),
                list(range(100)),
                list(range(100)) * 10,
                list(get_contract("PlainOpcodes", "Counter").bytecode),
            ],
            ids=[
                "10 bytes",
                "100 bytes",
                "1000 bytes",
                "Counter",
            ],
        )
        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_write_bytecode(self, cairo_run, bytecode):
            cairo_run("test__write_bytecode", bytecode=bytecode)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("bytecode_len_"), value=len(bytecode)
            )
            calls = [call(address=i, value=byte) for i, byte in enumerate(bytecode)]
            SyscallHandler.mock_storage.assert_has_calls(calls[::-1])
