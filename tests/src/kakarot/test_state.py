import pytest

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
        def test_account_in_state(self, cairo_run):
            cairo_run("test__is_account_warm__account_in_state")

        def test_not_in_state(self, cairo_run):
            cairo_run("test__is_account_warm__account_not_in_state")

    class TestCachePrecompiles:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        def test_should_cache_precompiles(self, cairo_run):
            output = cairo_run("test__cache_precompiles")
            assert output == list(range(1, 10))

    class TestCopyAccounts:
        def test_should_handle_null_pointers(self, cairo_run):
            cairo_run("test___copy_accounts__should_handle_null_pointers")
