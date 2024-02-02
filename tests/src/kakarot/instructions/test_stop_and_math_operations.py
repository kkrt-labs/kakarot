import pytest

from tests.utils.constants import Opcodes
from tests.utils.uint256 import int_to_uint256


class TestStopMathOperations:
    class TestStop:
        def test__exec_stop(self, cairo_run):
            cairo_run("test__exec_stop")

    class TestMathOperations:
        @pytest.mark.parametrize(
            "opcode,stack,expected_result",
            [
                (Opcodes.ADD, [3, 2, 1], 3 + 2),
                (Opcodes.MUL, [3, 2, 1], 3 * 2),
                (Opcodes.SUB, [3, 2, 1], 3 - 2),
                (Opcodes.DIV, [3, 2, 1], 3 // 2),
                (Opcodes.SDIV, [3, 2, 1], 3 // 2),
                (Opcodes.MOD, [3, 2, 1], 3 % 2),
                (Opcodes.SMOD, [3, 2, 1], 3 % 2),
                (Opcodes.ADDMOD, [3, 2, 2], (3 + 2) % 2),
                (Opcodes.MULMOD, [3, 2, 2], (3 * 2) % 2),
                (Opcodes.EXP, [3, 2], (3**2)),
                (Opcodes.EXP, [3, 1], (3**1)),
                (Opcodes.EXP, [3, 0], (3**0)),
                (
                    Opcodes.EXP,
                    [0xFF, 0x11],
                    (0xFF**0x11),
                ),
                (
                    Opcodes.SIGNEXTEND,
                    [
                        0x01,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0001,
                        3,
                    ],
                    0x01,
                ),
                (
                    Opcodes.SIGNEXTEND,
                    [0x00, 0xFF, 3],
                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                ),
                (
                    Opcodes.SIGNEXTEND,
                    [0x20, 0xFF, 3],
                    0xFF,
                ),
                (Opcodes.LT, [2, 1], 0),
                (Opcodes.LT, [1, 2], 1),
                (Opcodes.GT, [2, 1], 1),
                (Opcodes.GT, [1, 2], 0),
                (Opcodes.SLT, [1, 2], 1),
                (Opcodes.SLT, [2, 1], 0),
                (Opcodes.SGT, [1, 2], 0),
                (Opcodes.SGT, [2, 1], 1),
                (Opcodes.EQ, [1, 2], 0),
                (Opcodes.EQ, [2, 2], 1),
                (Opcodes.ISZERO, [1], 0),
                (Opcodes.ISZERO, [0], 1),
                (Opcodes.AND, [1, 0], 0),
                (Opcodes.AND, [1, 1], 1),
                (Opcodes.AND, [0xBD, 0xC9], 0x89),
                (Opcodes.OR, [0, 0], 0),
                (Opcodes.OR, [0, 1], 1),
                (Opcodes.OR, [0xC5, 0x89], 0xCD),
                (Opcodes.XOR, [1, 1], 0),
                (Opcodes.XOR, [0, 0], 0),
                (Opcodes.XOR, [0, 1], 1),
                (Opcodes.XOR, [1, 0], 1),
                (Opcodes.XOR, [0xDD, 0xB9], 0x64),
                (Opcodes.BYTE, [23, 0xFFEEDDCCBBAA998877665544332211], 0x99),
                (Opcodes.BYTE, [8, 0x123456789ABCDEF0 * 2**128], 0x12),
                (Opcodes.SHL, [4, 2], 32),
                (Opcodes.SHR, [2, 4], 1),
                (Opcodes.SAR, [2, 4], 1),
            ],
        )
        async def test__exec_math_operation(
            self, cairo_run, opcode, stack, expected_result
        ):
            stack = [tuple for value in stack for tuple in int_to_uint256(value)]
            output = cairo_run("test__exec_math_operation", opcode=opcode, stack=stack)
            expected_low, expected_high = int_to_uint256(expected_result)
            assert output[0] == expected_low
            assert output[1] == expected_high
