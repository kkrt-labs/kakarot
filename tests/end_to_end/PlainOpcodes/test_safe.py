import pytest
import pytest_asyncio

from kakarot_scripts.constants import DEFAULT_GAS_PRICE
from kakarot_scripts.utils.kakarot import deploy, eth_balance_of


@pytest_asyncio.fixture(scope="package")
async def safe():
    return await deploy("PlainOpcodes", "Safe")


@pytest.mark.asyncio(scope="package")
@pytest.mark.Safe
class TestSafe:
    class TestDeposit:
        async def test_should_receive_eth(self, safe):
            balance_before = await safe.balance()
            await safe.deposit(value=1)
            balance_after = await safe.balance()
            assert balance_after - balance_before == 1

    class TestWithdrawTransfer:
        async def test_should_withdraw_transfer_eth(self, safe, owner):
            await safe.deposit(value=1)

            safe_balance = await safe.balance()
            owner_balance_before = await eth_balance_of(owner.address)

            gas_used = (await safe.withdrawTransfer())["gas_used"]

            owner_balance_after = await eth_balance_of(owner.address)
            assert await safe.balance() == 0
            assert (
                owner_balance_after
                - owner_balance_before
                + gas_used * DEFAULT_GAS_PRICE
                == safe_balance
            )

    class TestWithdrawCall:
        async def test_should_withdraw_call_eth(self, safe, owner):
            await safe.deposit(value=ACCOUNT_BALANCE)

            safe_balance = await safe.balance()
            owner_balance_before = await eth_balance_of(owner.address)

            gas_used = (await safe.withdrawCall(caller_eoa=owner.starknet_contract))[
                "gas_used"
            ]

            owner_balance_after = await eth_balance_of(owner.address)
            assert await safe.balance() == 0
            assert (
                owner_balance_after
                - owner_balance_before
                + gas_used * DEFAULT_GAS_PRICE
                == safe_balance
            )

    class TestDeploySafeWithValue:
        async def test_deploy_safe_with_value(self):
            safe = await deploy("PlainOpcodes", "Safe", value=1)
            assert await safe.balance() == 1
