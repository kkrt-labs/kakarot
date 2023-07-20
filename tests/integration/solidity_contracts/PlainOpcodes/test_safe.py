import pytest


@pytest.mark.asyncio
@pytest.mark.Counter
@pytest.mark.usefixtures("starknet_snapshot")
class TestSafe:
    class TestReceive:
        async def test_should_receive_eth(self, safe, owner):
            await safe.deposit(value=1e9, caller_address=owner.starknet_address)
            assert await safe.balance() == 1e9

    class TestWithdraw:
        async def test_should_withdraw_eth(self, safe, owner):
            await safe.receive(value=1e9)
            await safe.withdraw(caller_address=owner.starknet_address)
            assert await safe.balance() == 0
