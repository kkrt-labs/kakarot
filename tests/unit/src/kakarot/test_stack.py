import re

import pytest
import pytest_asyncio


@pytest_asyncio.fixture
async def stack(starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/test_stack.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestStack:
    async def test_everything_stack(self, stack):
        await stack.test__init__should_return_an_empty_stack().call()
        await stack.test__len__should_return_the_length_of_the_stack().call()
        await stack.test__push__should_add_an_element_to_the_stack().call()
        await stack.test__pop__should_pop_an_element_to_the_stack().call()
        await stack.test__pop__should_pop_N_elements_to_the_stack().call()

        with pytest.raises(Exception) as e:
            await stack.test__pop__should_fail__when_stack_underflow_pop().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: StackUnderflow"

        with pytest.raises(Exception) as e:
            await stack.test__pop__should_fail__when_stack_underflow_pop_n().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: StackUnderflow"

        await stack.test__peek__should_return_stack_at_given_index__when_value_is_0().call()
        await stack.test__peek__should_return_stack_at_given_index__when_value_is_1().call()

        with pytest.raises(Exception) as e:
            await stack.test__peek__should_fail_when_underflow().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: StackUnderflow"

        await stack.test__swap__should_swap_2_stacks().call()

        with pytest.raises(Exception) as e:
            await stack.test__swap__should_fail__when_index_1_is_underflow().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: StackUnderflow"

        with pytest.raises(Exception) as e:
            await stack.test__swap__should_fail__when_index_2_is_underflow().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: StackUnderflow"
