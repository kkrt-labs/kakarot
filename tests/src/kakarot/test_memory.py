import pytest
import pytest_asyncio


@pytest_asyncio.fixture(scope="module")
async def memory(starknet):
    return await starknet.deploy(
        source="./tests/src/kakarot/test_memory.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestMemory:
    async def test_everything_memory(self, memory):
        await memory.test__init__should_return_an_empty_memory().call()
        await memory.test__len__should_return_the_length_of_the_memory().call()
        await memory.test__store__should_add_an_element_to_the_memory().call()
        await memory.test__load__should_load_an_element_from_the_memory().call()
        await memory.test__load__should_load_an_element_from_the_memory_with_offset(
            8, 2 * 256**8, 256**8
        ).call()
        await memory.test__load__should_load_an_element_from_the_memory_with_offset(
            7, 2 * 256**7, 256**7
        ).call()
        await memory.test__load__should_load_an_element_from_the_memory_with_offset(
            23, 3 * 256**7, 2 * 256**7
        ).call()
        await memory.test__load__should_load_an_element_from_the_memory_with_offset(
            33, 4 * 256**1, 3 * 256**1
        ).call()
        await memory.test__load__should_load_an_element_from_the_memory_with_offset(
            63, 0, 4 * 256**15
        ).call()
        await memory.test__load__should_load_an_element_from_the_memory_with_offset(
            500, 0, 0
        ).call()

        await memory.test__expand__should_return_the_same_memory_and_no_cost().call()
        await memory.test__expand__should_return_expanded_memory_and_cost().call()
        await memory.test__ensure_length__should_return_the_same_memory_and_no_cost().call()
        await memory.test__ensure_length__should_return_expanded_memory_and_cost().call()
        await memory.test__expand_and_load__should_return_expanded_memory_and_element_and_cost().call()
