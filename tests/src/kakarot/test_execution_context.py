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
        "jumpdest,new_pc,expected_return_data",
        [
            (0, 0, list(b"Kakarot: JUMP to non JUMPDEST")),
            (1, 1, []),
            (2, 0, list(b"Kakarot: ProgramCounterOutOfRange")),
        ],
    )
    async def test_jump(
        self, execution_context, jumpdest, new_pc, expected_return_data
    ):
        bytecode = [0, 0x5B]
        (pc, return_data) = (
            await execution_context.test__jump(bytecode, jumpdest).call()
        ).result
        assert pc == new_pc
        assert return_data == expected_return_data
