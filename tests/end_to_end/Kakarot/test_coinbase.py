import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy, eth_balance_of, fund_address
from kakarot_scripts.utils.starknet import invoke
from tests.utils.errors import evm_error


@pytest_asyncio.fixture(scope="package")
async def kakarot_eth(kakarot, eth):
    token = await deploy(
        "CairoPrecompiles", "DualVmToken", kakarot.address, eth.address
    )
    await invoke(
        "kakarot", "set_authorized_cairo_precompile_caller", int(token.address, 16), 1
    )
    return token


@pytest_asyncio.fixture(scope="package")
async def coinbase(owner, kakarot_eth):
    return await deploy(
        "Kakarot", "Coinbase", kakarot_eth.address, caller_eoa=owner.starknet_contract
    )


@pytest.mark.asyncio(scope="package")
class TestCoinbase:
    class TestWithdrawal:
        async def test_should_withdraw_all_eth(self, coinbase, owner):
            await fund_address(coinbase.address, 0.001)
            balance_coinbase_prev = await eth_balance_of(coinbase.address)
            balance_owner_prev = await eth_balance_of(owner.address)
            tx = await coinbase.withdraw(owner.starknet_contract.address)
            balance_coinbase = await eth_balance_of(coinbase.address)
            balance_owner = await eth_balance_of(owner.address)
            assert balance_coinbase_prev > 0
            assert balance_coinbase == 0
            assert balance_owner - balance_owner_prev + tx["gas_used"] == 0.001e18

        async def test_should_revert_when_not_owner(self, coinbase, other):
            with evm_error("Not the contract owner"):
                await coinbase.withdraw(0xDEAD, caller_eoa=other.starknet_contract)

    class TestTransferOwnership:
        async def test_should_transfer_ownership(self, coinbase, owner, other):
            await coinbase.transferOwnership(other.address)
            assert await coinbase.owner() == other.address
            await coinbase.transferOwnership(
                owner.address, caller_eoa=other.starknet_contract
            )

        async def test_should_revert_when_new_owner_is_zero_address(self, coinbase):
            with evm_error("New owner cannot be the zero address"):
                await coinbase.transferOwnership(f"0x{0:040x}")

        async def test_should_revert_when_not_owner(self, coinbase, other):
            with evm_error("Not the contract owner"):
                await coinbase.transferOwnership(
                    other.address, caller_eoa=other.starknet_contract
                )
