import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def memory_operations(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_memory_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestMemoryOperations:
    async def test_everything_memory(self, memory_operations):
        [
            await memory_operations.test__exec_pc__should_update_after_incrementing(
                increment=x
            ).call()
            for x in range(1, 15)
        ]
        await memory_operations.test__exec_pop_should_pop_an_item_from_execution_context().call()
        await memory_operations.test__exec_mload_should_load_a_value_from_memory().call()
        await memory_operations.test__exec_mload_should_load_a_value_from_memory_with_memory_expansion().call()
        await memory_operations.test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize().call()
