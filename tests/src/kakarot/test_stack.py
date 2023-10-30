import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def stack(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_stack.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestStack:
    class TestPeek:
        async def test_should_return_stack_at_given_index__when_value_is_0(self, stack):
            await stack.test__peek__should_return_stack_at_given_index__when_value_is_0().call()

        async def test_should_return_stack_at_given_index__when_value_is_1(self, stack):
            await stack.test__peek__should_return_stack_at_given_index__when_value_is_1().call()

    class TestInit:
        async def test_should_return_an_empty_stack(self, stack):
            await stack.test__init__should_return_an_empty_stack().call()

    class TestPush:
        async def test_should_add_an_element_to_the_stack(self, stack):
            await stack.test__push__should_add_an_element_to_the_stack().call()

    class TestPop:
        async def test_should_pop_an_element_to_the_stack(self, stack):
            await stack.test__pop__should_pop_an_element_to_the_stack().call()

        async def test_should_pop_N_elements_to_the_stack(self, stack):
            await stack.test__pop__should_pop_N_elements_to_the_stack().call()

    class TestSwap:
        async def test_should_swap_2_stacks(self, stack):
            await stack.test__swap__should_swap_2_stacks().call()
