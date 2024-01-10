import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def execution_context(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_execution_context.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestExecutionContext:
    @pytest.mark.parametrize(
        "bytecode, jumpdest, new_pc, expected_return_data",
        [
            ([0,0x5B], 0, 0, list(b"Kakarot: invalidJumpDestError")), # not 0x5b
            ([0,0x5B], 2, 0, list(b"Kakarot: invalidJumpDestError")), # out of bounds
            ([0,0x5B], 1, 1, []),
            ([0,0x60, 0x01, 0x5B], 3, 3, []), # post-push1 opcode
            ([0,0x61, 0x5B, 0x02], 2, 0, list(b"Kakarot: invalidJumpDestError")), # post-push2 opcode
        ],
    )
    async def test_jump(
        self, bytecode, execution_context, jumpdest, new_pc, expected_return_data
    ):
        (pc, return_data) = (
            await execution_context.test__jump(bytecode, jumpdest).call()
        ).result
        assert pc == new_pc
        assert return_data == expected_return_data
