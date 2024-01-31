import pytest
from ethereum.shanghai.fork_types import (
    TX_ACCESS_LIST_ADDRESS_COST,
    TX_ACCESS_LIST_STORAGE_KEY_COST,
)

from tests.utils.constants import TRANSACTIONS
from tests.utils.helpers import sanitize_access_list
from tests.utils.syscall_handler import SyscallHandler


class TestState:
    class TestInit:
        def test_should_return_state_with_default_dicts(self, cairo_run):
            cairo_run("test__init__should_return_state_with_default_dicts")

    class TestCopy:
        @SyscallHandler.patch(
            "IAccount.account_type", lambda addr, data: [int.from_bytes(b"EOA", "big")]
        )
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        def test_should_return_new_state_with_same_attributes(self, cairo_run):
            cairo_run("test__copy__should_return_new_state_with_same_attributes")

    class TestIsAccountAlive:
        @pytest.mark.parametrize(
            "nonce, code, balance_low, expected_result",
            (
                (0, [], 0, False),
                (1, [], 0, True),
                (0, [1], 0, True),
                (0, [], 1, True),
            ),
        )
        def test_existing_account(
            self, cairo_run, nonce, code, balance_low, expected_result
        ):
            output = cairo_run(
                "test__is_account_alive__existing_account",
                nonce=nonce,
                code=code,
                balance_low=balance_low,
            )
            assert output[0] == expected_result

        def test_not_in_state(self, cairo_run):
            cairo_run("test__is_account_alive__not_in_state")

    class TestIsAccountWarm:
        def test_should_return_true_when_account_in_state(self, cairo_run):
            cairo_run("test__is_account_warm__account_in_state")

        def test_should_return_false_when_account_not_state(self, cairo_run):
            cairo_run("test__is_account_warm__account_not_in_state")

    class TestIsStorageWarm:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        def test_should_return_true_when_already_read(self, cairo_run):
            cairo_run("test__is_storage_warm__should_return_true_when_already_read")

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        def test_should_return_true_when_already_written(self, cairo_run):
            cairo_run("test__is_storage_warm__should_return_true_when_already_written")

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        def test_should_return_false_when_not_accessed(self, cairo_run):
            cairo_run("test__is_storage_warm__should_return_false_when_not_accessed")

    class TestCachePreaccessedAddresses:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        def test_should_cache_precompiles(self, cairo_run):
            output = cairo_run("test__cache_precompiles")
            assert output == list(range(1, 10))

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        def test_should_cache_access_list(self, cairo_run, transaction):
            access_list = transaction.get("accessList", ())

            # Remove duplicates from addresses and addresses's storage keys
            sanitized_access_list = sanitize_access_list(access_list)

            gas_cost = cairo_run(
                "test__cache_access_list",
                access_list=access_list,
                sanitized_access_list=sanitized_access_list,
            )[0]

            unique_address_count = len(sanitized_access_list)
            total_unique_storage_keys = sum(
                len(item["storageKeys"]) for item in sanitized_access_list
            )
            assert (
                gas_cost
                == TX_ACCESS_LIST_ADDRESS_COST * unique_address_count
                + TX_ACCESS_LIST_STORAGE_KEY_COST * total_unique_storage_keys
            )

    class TestCopyAccounts:
        def test_should_handle_null_pointers(self, cairo_run):
            cairo_run("test___copy_accounts__should_handle_null_pointers")
