import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error
from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="module")
async def push_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/instructions/test_push_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestPushOperations:
    @pytest.mark.parametrize("i", range(2, 33))
    async def test__exec_push_should_raise(self, push_operations, i):
        with kakarot_error():
            await push_operations.test__exec_push_should_raise(i).call()

    @pytest.mark.parametrize("i", range(1, 33))
    async def test__exec_push_should_push(self, push_operations, i):
        res = await push_operations.test__exec_push_should_push(i).call()
        assert res.result.value == int_to_uint256(256**i - 1)
