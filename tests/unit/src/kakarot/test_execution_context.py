import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error


@pytest_asyncio.fixture(scope="module")
async def execution_context(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/test_execution_context.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestExecutionContext:
    async def test_everything_context(self, execution_context):
        await execution_context.test__init__should_return_an_empty_execution_context().call()
        await execution_context.test__update_program_counter__should_set_pc_to_given_value().call()
        with kakarot_error("Kakarot: new pc target out of range"):
            await execution_context.test__update_program_counter__should_fail__when_given_value_not_in_code_range().call()

        with kakarot_error("Kakarot: JUMPed to pc offset is not JUMPDEST"):
            await execution_context.test__update_program_counter__should_fail__when_given_destination_that_is_not_JUMPDEST().call()
