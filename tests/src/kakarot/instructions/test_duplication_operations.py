import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def duplication_operations(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_duplication_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestDupOperations:
    @pytest.mark.parametrize("i", range(1, 17))
    async def test__exec_dup(self, duplication_operations, i):
        stack = [(v, 0) for v in range(16)]
        (result,) = (
            await duplication_operations.test__exec_dup(i, stack).call()
        ).result
        assert result == stack[-i]
