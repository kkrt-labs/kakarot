import pytest
from hypothesis import given
from hypothesis.strategies import integers

from tests.utils.syscall_handler import SyscallHandler


class TestExecutionContext:
    @pytest.mark.parametrize(
        "bytecode, jumpdest, new_pc, expected_return_data",
        [
            ([0, 0x5B], 0, 0, list(b"Kakarot: invalidJumpDestError")),  # not 0x5b
            ([0, 0x5B], 2, 0, list(b"Kakarot: invalidJumpDestError")),  # out of bounds
            ([0, 0x5B], 1, 1, []),
            ([0, 0x60, 0x01, 0x5B], 3, 3, []),  # post-push1 opcode
            (
                [0, 0x61, 0x5B, 0x02],
                2,
                0,
                list(b"Kakarot: invalidJumpDestError"),
            ),  # post-push2 opcode
        ],
    )
    @SyscallHandler.patch(
        "IERC20.balanceOf",
        lambda addr, data: [0, 0],
    )
    def test_jump(self, cairo_run, bytecode, jumpdest, new_pc, expected_return_data):

        with SyscallHandler.patch(
            "IAccount.is_valid_jumpdest",
            lambda addr, data: [1 if len(expected_return_data) == 0 else 0],
        ):
            evm = cairo_run("test__jump", bytecode=bytecode, jumpdest=jumpdest)
        assert evm["program_counter"] == new_pc
        assert evm["return_data"] == expected_return_data


class TestIsValidJumpdest:
    @pytest.mark.parametrize(
        "cached_jumpdests, index, expected",
        [
            ({0x01: True, 0x10: True, 0x101: True}, 0x10, 1),
            ({0x01: True, 0x10: True, 0x101: True}, 0x101, 1),
        ],
    )
    def test_should_return_cached_valid_jumpdest(
        self, cairo_run, cached_jumpdests, index, expected
    ):
        assert (
            cairo_run(
                "test__is_valid_jumpdest",
                cached_jumpdests=cached_jumpdests,
                index=index,
            )
            == expected
        )

    @SyscallHandler.patch(
        "IERC20.balanceOf",
        lambda addr, data: [0, 0],
    )
    @SyscallHandler.patch(
        "IAccount.is_valid_jumpdest",
        lambda addr, data: [1 if data == [0x10] else 0],
    )
    @pytest.mark.parametrize(
        "cached_jumpdests, index, expected",
        [
            ({}, 0x10, 1),
            ({}, 0x102, 0),
        ],
    )
    def test_should_return_non_cached_valid_jumpdest(
        self, cairo_run, cached_jumpdests, index, expected
    ):
        assert (
            cairo_run(
                "test__is_valid_jumpdest",
                cached_jumpdests=cached_jumpdests,
                index=index,
            )
            == expected
        )

    # 1000000 is the default value for the init_evm test helper
    @given(amount=integers(min_value=0, max_value=1000000))
    def test_should_return_gas_left(self, cairo_run, amount):
        output = cairo_run("test__charge_gas", amount=amount)
        assert output[0] == 1000000 - amount  # gas_left
        assert output[1] == 0  # stopped

    # 1000000 is the default value for the init_evm test helper
    @given(amount=integers(min_value=1000001, max_value=2**248 - 1))
    def test_should_return_not_enough_gas(self, cairo_run, amount):
        output = cairo_run("test__charge_gas", amount=amount)
        assert output[0] == 0  # gas_left
        assert output[1] == 1  # stopped
