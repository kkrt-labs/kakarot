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
    async def test_everything_context(self, execution_context):
        await execution_context.test__init__should_return_an_empty_execution_context().call()
        await execution_context.test__jump__should_set_pc_to_given_value().call()

        result = (
            await execution_context.test__jump__should_fail__when_given_value_not_in_code_range().call()
        )
        assert result.result.revert_reason == list(b"Kakarot: ProgramCounterOutOfRange")

        result = (
            await execution_context.test__jump__should_fail__when_given_destination_that_is_not_JUMPDEST().call()
        )
        assert result.result.revert_reason == list(b"Kakarot: JUMP to non JUMPDEST")
