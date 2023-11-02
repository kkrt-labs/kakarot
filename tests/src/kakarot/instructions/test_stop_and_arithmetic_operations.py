import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.constants import Opcodes
from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="module")
async def arithmetic_operations(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_stop_and_arithmetic_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestStopAndArithmeticOperations:
    class TestStop:
        async def test__exec_stop(self, arithmetic_operations):
            await arithmetic_operations.test__exec_stop().call()

    class TestArithmeticOperations:
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
                (Opcodes.EXP, [3, 2, 1], (3**2)),
                (Opcodes.SIGNEXTEND, [3, 2, 1], 2),
            ],
        )
        async def test__exec_arithmetic_operation(
            self, arithmetic_operations, opcode, stack, expected_result
        ):
            await arithmetic_operations.test__exec_arithmetic_operation(
                opcode,
                [int_to_uint256(v) for v in stack],
                int_to_uint256(expected_result),
            ).call()
