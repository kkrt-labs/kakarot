import pytest

from tests.utils.constants import ACCOUNT_BALANCE


@pytest.mark.asyncio
@pytest.mark.Safe
@pytest.mark.usefixtures("starknet_snapshot")
class TestSafe:
    class TestReceive:
        async def test_should_receive_eth(self, safe, owner):
            await safe.deposit(value=ACCOUNT_BALANCE, caller_address=owner)
            assert await safe.balance() == ACCOUNT_BALANCE

    class TestWithdrawTransfer:
        async def test_should_withdraw_transfer_eth(self, safe, owner, eth):
            await safe.deposit(value=ACCOUNT_BALANCE, caller_address=owner)
            await safe.withdrawTransfer(caller_address=owner)
            assert await safe.balance() == 0
            assert (
                await eth.balanceOf(owner.starknet_address).call()
            ).result.balance.low == ACCOUNT_BALANCE

    class TestWithdrawCall:
        async def test_should_withdraw_call_eth(self, safe, owner, eth):
            await safe.deposit(value=ACCOUNT_BALANCE, caller_address=owner)
            await safe.withdrawCall(caller_address=owner)
            assert await safe.balance() == 0
            assert (
                await eth.balanceOf(owner.starknet_address).call()
            ).result.balance.low == ACCOUNT_BALANCE

    class TestDeploySafeWithValue:
        async def test_deploy_safe_with_value(
            self, safe, deploy_solidity_contract
        ):
            safe = await deploy_solidity_contract(
                "PlainOpcodes", "Safe", value=1
            )
            assert await safe.balance() == 1
