import pytest
import pytest_asyncio

from kakarot_scripts.constants import DEFAULT_GAS_PRICE
from tests.utils.constants import ACCOUNT_BALANCE


@pytest_asyncio.fixture(scope="package")
async def owner(new_eoa):
    return await new_eoa()


@pytest_asyncio.fixture(scope="package")
async def safe(deploy_contract, owner):
    return await deploy_contract(
        "PlainOpcodes", "Safe", caller_eoa=owner.starknet_contract
    )


@pytest.mark.asyncio(scope="package")
@pytest.mark.Safe
class TestSafe:
    class TestReceive:
        async def test_should_receive_eth(self, safe, owner):
            balance_before = await safe.balance()
            await safe.deposit(
                value=ACCOUNT_BALANCE, caller_eoa=owner.starknet_contract
            )
            balance_after = await safe.balance()
            assert balance_after - balance_before == ACCOUNT_BALANCE

    class TestWithdrawTransfer:
        async def test_should_withdraw_transfer_eth(self, safe, owner, eth_balance_of):
            await safe.deposit(
                value=ACCOUNT_BALANCE, caller_eoa=owner.starknet_contract
            )

            safe_balance = await safe.balance()
            owner_balance_before = await eth_balance_of(owner.address)

            gas_used = (
                await safe.withdrawTransfer(caller_eoa=owner.starknet_contract)
            )["gas_used"]

            owner_balance_after = await eth_balance_of(owner.address)
            assert await safe.balance() == 0
            assert (
                owner_balance_after
                - owner_balance_before
                + gas_used * DEFAULT_GAS_PRICE
                == safe_balance
            )

    class TestWithdrawCall:
        async def test_should_withdraw_call_eth(self, safe, owner, eth_balance_of):
            await safe.deposit(
                value=ACCOUNT_BALANCE, caller_eoa=owner.starknet_contract
            )

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
        async def test_deploy_safe_with_value(self, safe, deploy_contract, owner):
            safe = await deploy_contract(
                "PlainOpcodes",
                "Safe",
                caller_eoa=owner.starknet_contract,
                value=1,
            )
            assert await safe.balance() == 1
