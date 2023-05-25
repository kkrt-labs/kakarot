import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error
from tests.utils.helpers import extract_stack_from_execute
from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="module")
async def push_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/src/kakarot/instructions/test_push_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestPushOperations:
    @pytest.mark.parametrize("i", range(2, 33))
    async def test__exec_push_should_raise(self, push_operations, i):
        with kakarot_error():
            await push_operations.test__exec_push_should_raise(i).call()

    @pytest.mark.parametrize("i", range(0, 33))
    async def test__exec_push_should_push(self, push_operations, i):
        res = await push_operations.test__exec_push_should_push(i).call()
        assert res.result.value == int_to_uint256(256**i - 1)

    # per https://eips.ethereum.org/EIPS/eip-3855,
    # we want to check that
    # we can push0 1024 times, where all values are zero
    async def test__exec_push0_should_push_to_stack_max_depth(self, push_operations):
        stack_len = 1024
        res = await push_operations.test__exec_push_should_push_n_times(
            stack_len, 0
        ).call()
        stack = extract_stack_from_execute(res.result)
        assert stack == [0] * stack_len

    # we can push0 1025 times, causing a stackoverlfow
    # it seems that our logic throws at 1026
    async def test__exec_push0_should_overflow(self, push_operations):
        stack_len = 1026
        with kakarot_error("Kakarot: StackOverflow"):
            await push_operations.test__exec_push_should_push_n_times(
                stack_len, 0
            ).call()
