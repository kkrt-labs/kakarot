import re

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def execution_context(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/cairo_files/instructions/test_exchange_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
class TestExchangeOperationst:
    async def test_everything_context(self, execution_context):
        await execution_context.test__util_prepare_stack__should_create_stack_with_top_and_preswapped_elements().call()
        await execution_context.test__exec_swap1__should_swap_1st_and_2nd().call()
        await execution_context.test__exec_swap2__should_swap_1st_and_3rd().call()

        with pytest.raises(Exception) as e:
            await execution_context.test__exec_swap1__should_fail__when_index_1_is_underflow().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: StackUnderflow"

        with pytest.raises(Exception) as e:
            await execution_context.test__exec_swap2__should_fail__when_index_2_is_underflow().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: StackUnderflow"
