import pytest


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
        pc, _, *return_data = cairo_run(
            "test__jump", bytecode=bytecode, jumpdest=jumpdest
        )
        assert pc == new_pc
        assert return_data == expected_return_data
