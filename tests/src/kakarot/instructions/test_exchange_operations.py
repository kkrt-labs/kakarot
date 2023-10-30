import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def exchange_operations(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_exchange_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestExchangeOperations:
    class TestInitStack:
        async def test_should_create_stack_with_top_and_preswapped_elements(
            self, exchange_operations
        ):
            await exchange_operations.test__util_init_stack__should_create_stack_with_top_and_preswapped_elements().call()

    class TestSwap1:
        async def test_should_swap_1st_and_2nd(self, exchange_operations):
            await exchange_operations.test__exec_swap1__should_swap_1st_and_2nd().call()

    class TestSwap2:
        async def test_should_swap_1st_and_3rd(self, exchange_operations):
            await exchange_operations.test__exec_swap2__should_swap_1st_and_3rd().call()

    class TestSwap8:
        async def test_should_swap_1st_and_9th(self, exchange_operations):
            await exchange_operations.test__exec_swap8__should_swap_1st_and_9th().call()

    class TestSwap9:
        async def test_should_swap_1st_and_10th(self, exchange_operations):
            await exchange_operations.test__exec_swap9__should_swap_1st_and_10th().call()

    class TestSwap10:
        async def test_should_swap_1st_and_11th(self, exchange_operations):
            await exchange_operations.test__exec_swap10__should_swap_1st_and_11th().call()

    class TestSwap11:
        async def test_should_swap_1st_and_12th(self, exchange_operations):
            await exchange_operations.test__exec_swap11__should_swap_1st_and_12th().call()

    class TestSwap12:
        async def test_should_swap_1st_and_13th(self, exchange_operations):
            await exchange_operations.test__exec_swap12__should_swap_1st_and_13th().call()

    class TestSwap13:
        async def test_should_swap_1st_and_14th(self, exchange_operations):
            await exchange_operations.test__exec_swap13__should_swap_1st_and_14th().call()

    class TestSwap14:
        async def test_should_swap_1st_and_15th(self, exchange_operations):
            await exchange_operations.test__exec_swap14__should_swap_1st_and_15th().call()

    class TestSwap15:
        async def test_should_swap_1st_and_16th(self, exchange_operations):
            await exchange_operations.test__exec_swap15__should_swap_1st_and_16th().call()

    class TestSwap16:
        async def test_should_swap_1st_and_17th(self, exchange_operations):
            await exchange_operations.test__exec_swap16__should_swap_1st_and_17th().call()
