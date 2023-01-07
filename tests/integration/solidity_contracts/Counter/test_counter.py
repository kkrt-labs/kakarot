import re

import pytest


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
            with pytest.raises(Exception) as e:
                await counter.dec(caller_address=addresses[1].starknet_address)
            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert message == "Kakarot: Reverted with reason: 32"

        async def test_should_decrease_count(self, counter, addresses):
            await counter.inc(caller_address=addresses[1].starknet_address)
            await counter.dec(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 0

    class TestReset:
        async def test_should_set_count_to_0(self, counter, addresses):
            await counter.inc(caller_address=addresses[1].starknet_address)
            await counter.reset(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 0
