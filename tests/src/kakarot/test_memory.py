import pytest
import pytest_asyncio
from ethereum.shanghai.vm.gas import calculate_memory_gas_cost
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def memory(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_memory.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestMemory:
    class TestInit:
        async def test_should_return_an_empty_memory(self, memory):
            await memory.test__init__should_return_an_empty_memory().call()

    class TestStore:
        async def test_should_add_an_element_to_the_memory(self, memory):
            await memory.test__store__should_add_an_element_to_the_memory().call()

    class TestLoad:
        @pytest.mark.parametrize(
            "offset, low, high",
            [
                (8, 2 * 256**8, 256**8),
                (7, 2 * 256**7, 256**7),
                (23, 3 * 256**7, 2 * 256**7),
                (33, 4 * 256**1, 3 * 256**1),
                (63, 0, 4 * 256**15),
                (500, 0, 0),
            ],
        )
        async def test_should_load_an_element_from_the_memory_with_offset(
            self, memory, offset, low, high
        ):
            await memory.test__load__should_load_an_element_from_the_memory_with_offset(
                offset, low, high
            ).call()

        async def test_should_expand_memory_and_return_element(self, memory):
            await memory.test__load__should_expand_memory_and_return_element().call()

    class TestCost:
        @pytest.mark.parametrize("max_offset", [0, 0xFF, 0xFFFF, 0xFFFFFF, 0xFFFFFFFF])
        async def test_should_return_same_as_execution_specs(self, memory, max_offset):
            assert (
                calculate_memory_gas_cost(max_offset)
                == (await memory.test__cost((max_offset + 31) // 32).call()).result.cost
            )
