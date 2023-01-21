import pytest

from tests.utils.errors import kakarot_error


@pytest.mark.asyncio
@pytest.mark.Counter
@pytest.mark.usefixtures("starknet_snapshot")
class TestCounter:
    class TestCount:
        async def test_should_return_0_after_deployment(self, counter):
            assert await counter.count() == 0

    class TestInc:
        async def test_should_increase_count(self, counter, addresses):
            await counter.inc(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 1

    class TestDec:
        async def test_should_raise_when_count_is_0(self, counter, addresses):
            with kakarot_error("count should be strictly greater than 0"):
                await counter.dec(caller_address=addresses[1].starknet_address)

        async def test_should_decrease_count(self, counter, addresses):
            await counter.inc(caller_address=addresses[1].starknet_address)
            await counter.dec(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 0

        async def test_should_decrease_count_unchecked(self, counter, addresses):
            await counter.inc(caller_address=addresses[1].starknet_address)
            await counter.decUnchecked(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 0

        async def test_should_decrease_count_in_place(self, counter, addresses):
            await counter.inc(caller_address=addresses[1].starknet_address)
            await counter.decInPlace(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 0

    class TestReset:
        async def test_should_set_count_to_0(self, counter, addresses):
            await counter.inc(caller_address=addresses[1].starknet_address)
            await counter.reset(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 0
