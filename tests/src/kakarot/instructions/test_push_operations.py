import pytest

from tests.utils.uint256 import int_to_uint256


@pytest.mark.asyncio
class TestPushOperations:
    # The `exec_push` is tested by initializing the bytecode with a fill value of 0xFF.
    # As we push 'i' bytes onto the stack,
    # this results in a stack value of 0xFF repeated 'i' times.
    # In decimal notation, this is equivalent to 256**i - 1,
    # which forms the basis of our assertion in this test.
    @pytest.mark.parametrize("i", range(0, 33))
    async def test__exec_push(self, cairo_run, i):
        output = cairo_run("test__exec_push", i=i)
        assert tuple(output) == int_to_uint256(256**i - 1)
