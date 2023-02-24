import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet
from tests.utils.errors import kakarot_error

@pytest_asyncio.fixture(scope="module")
async def push_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/instructions/test_push_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )

@pytest.mark.asyncio
class TestPushOperations:
    @pytest.mark.parametrize('i', range(2, 33))
    async def test__exec_push_should_raise(self, push_operations, i):
        with kakarot_error():
            await push_operations.test__exec_push_should_raise(i).call()

    @pytest.mark.parametrize('i', range(1, 17))
    async def test__exec_push_should_add_1_through_16_bytes_to_stack(self, push_operations, i):
        await push_operations.test__exec_push_should_add_1_through_16_bytes_to_stack(i).call()

    @pytest.mark.parametrize('i', range(17, 33))
    async def test__exec_push_should_add_17_through_32_bytes_to_stack(self, push_operations, i):
        await push_operations.test__exec_push_should_add_17_through_32_bytes_to_stack(i).call()