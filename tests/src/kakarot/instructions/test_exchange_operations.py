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
class TestSwapOperations:
    @pytest.mark.parametrize("i", range(1, 17))
    async def test__exec_swap(self, exchange_operations, i):
        stack = [(v, 0) for v in range(17)]
        (top, swapped) = (
            await exchange_operations.test__exec_swap(i, stack).call()
        ).result
        assert top == stack[i]
        assert swapped == stack[0]
