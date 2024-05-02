import pytest

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
    def test_jump(self, cairo_run, bytecode, jumpdest, new_pc, expected_return_data):

        with SyscallHandler.patch(
            "IAccount.is_valid_jumpdest",
            lambda addr, data: [1 if len(expected_return_data) == 0 else 0],
        ):
            evm = cairo_run("test__jump", bytecode=bytecode, jumpdest=jumpdest)
        assert evm["program_counter"] == new_pc
        assert evm["return_data"] == expected_return_data


class TestIsJumpdestValid:
    @pytest.mark.parametrize(
        "cached_jumpdests, index, expected",
        [
            ([0x01, 0x10, 0x101], 0x10, 1),
            ([0x01, 0x10, 0x101], 0x101, 1),
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
        "IAccount.is_valid_jumpdest",
        lambda addr, data: [1 if data == [0x10] else 0],
    )
    @pytest.mark.parametrize(
        "cached_jumpdests, index, expected",
        [
            ([], 0x10, 1),
            ([], 0x102, 0),
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
