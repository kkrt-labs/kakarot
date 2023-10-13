import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import cairo_error
from tests.utils.helpers import extract_stack_from_execute
from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="module")
async def push_operations(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_push_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestPushOperations:
    @pytest.mark.parametrize("i", range(2, 33))
    async def test__exec_push_should_raise(self, push_operations, i):
        with cairo_error():
            await push_operations.test__exec_push_should_raise(i).call()

    # The `exec_push_i` is tested by initializing the bytecode with a fill value of 0xFF.
    # As we push 'i' bytes onto the stack,
    # this results in a stack value of 0xFF repeated 'i' times.
    # In decimal notation, this is equivalent to 256**i - 1,
    # which forms the basis of our assertion in this test.
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

    # we cannot push0 1025 times -> there should be a stackoverlfow
    # our impl throws at 1026
    async def test__exec_push0_should_overflow(self, push_operations):
        stack_len = 1026
        with cairo_error("Kakarot: StackOverflow"):
            await push_operations.test__exec_push_should_push_n_times(
                stack_len, 0
            ).call()
