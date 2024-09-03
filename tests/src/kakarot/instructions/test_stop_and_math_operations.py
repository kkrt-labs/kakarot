import pytest

from kakarot_scripts.utils.uint256 import int_to_uint256
from tests.utils.constants import Opcodes


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
                (Opcodes.ADDMOD, [3, 2, 2], (3 + 2) % 2),
                (
                    Opcodes.ADDMOD,
                    [
                        0x92343C8FA1D4651383994E908DC7A65B8AE59BB5161379B3B4D8EB2881C3A8A1,
                        0x9F728D298865647B33FBBEF974967E10D881FCCA251FB1FB72F314033E17E76A,
                        0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF,
                    ],
                    0x31A6C9BA2A39C98DB7950D8A025E246C6367987E3B332BAF27CBFF2BBFDB900C,
                ),
                (
                    Opcodes.MULMOD,
                    [
                        0xCAD9D0F127DE33D7EEAC15ACD9232B4FB7D4ABBD9E4AC4AC2F044EA995F80831,
                        0xCAD9D0F127DE33D7EEAC15ACD9232B4FB7D4ABBD9E4AC4AC2F044EA995F80831,
                        0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF,
                    ],
                    0xE6228DFC2D312EF258CB5EA9536EBAD8D6EDE5BE03564700D6878D191844E865,
                ),
                (
                    Opcodes.MULMOD,
                    [
                        0xE6228DFC2D312EF258CB5EA9536EBAD8D6EDE5BE03564700D6878D191844E865,
                        0xCAD9D0F127DE33D7EEAC15ACD9232B4FB7D4ABBD9E4AC4AC2F044EA995F80831,
                        0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF,
                    ],
                    0x92343C8FA1D4651383994E908DC7A65B8AE59BB5161379B3B4D8EB2881C3A8A1,
                ),
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
                (
                    Opcodes.BYTE,
                    [
                        0x8000000000000000000000000000000000000000000000000000000000000000,  # zellic issue 1260
                        0x11223344556677889900AABBCCDDEEFF11223344556677889900AABBCCDDEEFF,
                    ],
                    0x00,
                ),
                (Opcodes.SHL, [4, 2], 32),
                (Opcodes.SHR, [2, 4], 1),
                (Opcodes.SAR, [2, 4], 1),
            ],
        )
        def test__exec_math_operation(self, cairo_run, opcode, stack, expected_result):
            stack = [
                u256_member for value in stack for u256_member in int_to_uint256(value)
            ]
            (evm, result) = cairo_run(
                "test__exec_math_operation", opcode=opcode, stack=stack
            )
            assert int(result, 16) == expected_result

        @pytest.mark.parametrize(
            "opcode, stack", [(0x0C, []), (0x0D, []), (0x0E, []), (0x0F, [])]
        )
        def test__invalid_opcode_should_revert(self, cairo_run, opcode, stack):
            (evm, result) = cairo_run(
                "test__exec_math_operation", opcode=opcode, stack=stack
            )
            assert evm["reverted"] == 2
