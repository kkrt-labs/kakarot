import pytest
from ethereum.shanghai.vm.runtime import get_valid_jump_destinations

from kakarot_scripts.utils.kakarot import get_contract
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256


class TestAccount:
    class TestInit:
        @pytest.mark.parametrize(
            "address, code, nonce, balance",
            [(0, [], 0, 0), (2**160 - 1, [1, 2, 3], 1, 1)],
        )
        def test_should_return_account_with_default_dict_as_storage(
            self, cairo_run, address, code, nonce, balance
        ):
            cairo_run(
                "test__init__should_return_account_with_default_dict_as_storage",
                evm_address=address,
                code=code,
                nonce=nonce,
                balance_low=balance,
            )

    class TestCopy:
        @pytest.mark.parametrize(
            "address, code, nonce, balance",
            [(0, [], 0, 0), (2**160 - 1, [1, 2, 3], 1, 1)],
        )
        def test_should_return_new_account_with_same_attributes(
            self, cairo_run, address, code, nonce, balance
        ):
            cairo_run(
                "test__copy__should_return_new_account_with_same_attributes",
                evm_address=address,
                code=code,
                nonce=nonce,
                balance_low=balance,
            )

    class TestWriteStorage:
        @pytest.mark.parametrize("key, value", [(0, 0), (2**256 - 1, 2**256 - 1)])
        def test_should_store_value_at_key(self, cairo_run, key, value):
            cairo_run(
                "test__write_storage__should_store_value_at_key",
                key=int_to_uint256(key),
                value=int_to_uint256(value),
            )

    class TestOriginalStorage:
        @pytest.mark.parametrize("key, value", [(0, 0), (2**256 - 1, 2**256 - 1)])
        @SyscallHandler.patch(
            "IContractAccount.storage", lambda addr, data: [0x1337, 0]
        )
        @SyscallHandler.patch("evm_to_starknet_address", 0xABDE1, 0x1234)
        def test_should_return_original_storage_when_state_modified(
            self, cairo_run, key, value
        ):
            address = 0xABDE1
            output = cairo_run(
                "test__fetch_original_storage__state_modified",
                address=address,
                key=int_to_uint256(key),
                value=int_to_uint256(value),
            )
            assert output == "0x1337"

        @SyscallHandler.patch(
            "evm_to_starknet_address",
            0xABDE1,
            0,
        )
        @pytest.mark.parametrize("key, value", [(0, 0), (2**256 - 1, 2**256 - 1)])
        def test_should_return_zero_account_not_registered(self, cairo_run, key, value):
            address = 0xABDE1
            output = cairo_run(
                "test__fetch_original_storage__state_modified",
                address=address,
                key=int_to_uint256(key),
                value=int_to_uint256(value),
            )
            assert output == "0x0"

    class TestHasCodeOrNonce:
        @pytest.mark.parametrize(
            "nonce,code,expected_result",
            (
                (0, [], False),
                (1, [], True),
                (0, [1], True),
                (1, [1], True),
            ),
        )
        def test_should_return_true_when_nonce(
            self, cairo_run, nonce, code, expected_result
        ):
            output = cairo_run("test__has_code_or_nonce", nonce=nonce, code=code)
            assert output == expected_result

    class TestGetJumpdests:
        def test_should_return_same_as_execution_specs(self, cairo_run):
            bytecode = get_contract("PlainOpcodes", "Counter").bytecode_runtime
            output = cairo_run("test__get_jumpdests", bytecode=bytecode)
            assert set(output) == get_valid_jump_destinations(bytecode)
