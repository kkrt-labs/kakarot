import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error


@pytest_asyncio.fixture
async def stack(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_stack.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestStack:
    async def test_everything_stack(self, stack):
        await stack.test__init__should_return_an_empty_stack().call()
        await stack.test__len__should_return_the_length_of_the_stack().call()
        await stack.test__push__should_add_an_element_to_the_stack().call()
        await stack.test__pop__should_pop_an_element_to_the_stack().call()
        await stack.test__pop__should_pop_N_elements_to_the_stack().call()

        with kakarot_error("Kakarot: StackUnderflow"):
            await stack.test__pop__should_fail__when_stack_underflow_pop().call()

        with kakarot_error("Kakarot: StackUnderflow"):
            await stack.test__pop__should_fail__when_stack_underflow_pop_n().call()

        await stack.test__peek__should_return_stack_at_given_index__when_value_is_0().call()
        await stack.test__peek__should_return_stack_at_given_index__when_value_is_1().call()

        with kakarot_error("Kakarot: StackUnderflow"):
            await stack.test__peek__should_fail_when_underflow().call()

        await stack.test__swap__should_swap_2_stacks().call()

        with kakarot_error("Kakarot: StackUnderflow"):
            await stack.test__swap__should_fail__when_index_1_is_underflow().call()

        with kakarot_error("Kakarot: StackUnderflow"):
            await stack.test__swap__should_fail__when_index_2_is_underflow().call()
