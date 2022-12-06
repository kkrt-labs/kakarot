import re

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def execution_context(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/kakarot/test_execution_context.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestExecutionContext:
    async def test_everything_context(self, execution_context):
        await execution_context.test__init__should_return_an_empty_execution_context().call()
        await execution_context.test__update_program_counter__should_set_pc_to_given_value().call()
        with pytest.raises(Exception) as e:
            await execution_context.test__update_program_counter__should_fail__when_given_value_not_in_code_range().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: new pc target out of range"

        with pytest.raises(Exception) as e:
            await execution_context.test__update_program_counter__should_fail__when_given_destination_that_is_not_JUMPDEST().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: JUMPed to pc offset is not JUMPDEST"
