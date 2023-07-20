import pytest


@pytest.mark.asyncio
@pytest.mark.Counter
@pytest.mark.usefixtures("starknet_snapshot")
class TestSafe:
    class TestReceive:
        async def test_should_receive_eth(self, safe, owner, eth):
            await eth.mint(owner.starknet_address, (int(1e9), 0)).execute(caller_address=owner.starknet_address)
            await safe.deposit(value=int(1e9), caller_address=owner.starknet_address)
            assert await safe.balance() == 1e9

    class TestWithdrawTransfer:
        async def test_should_withdraw_transfer_eth(self, safe, owner, eth):
            await eth.mint(owner.starknet_address, (int(1e9), 0)).execute(caller_address=owner.starknet_address)
            await safe.deposit(value=int(1e9), caller_address=owner.starknet_address)
            await safe.withdrawTransfer(caller_address=owner.starknet_address)
            assert await safe.balance() == 0
            assert (await eth.balanceOf(owner.starknet_address).call()).result.balance.low == 1e9

    class TestWithdrawCall:
        async def test_should_withdraw_call_eth(self, safe, owner, eth):
            await eth.mint(owner.starknet_address, (int(1e9), 0)).execute(caller_address=owner.starknet_address)
            await safe.deposit(value=int(1e9), caller_address=owner.starknet_address)
            await safe.withdrawCall(caller_address=owner.starknet_address)
            assert await safe.balance() == 0
            assert (await eth.balanceOf(owner.starknet_address).call()).result.balance.low == 1e9