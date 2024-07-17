import pytest
import pytest_asyncio

from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import get_contract as get_contract_starknet
from kakarot_scripts.utils.starknet import get_deployments


@pytest_asyncio.fixture()
async def starknetToken(invoke, owner):
    address = (
        await deploy_starknet(
            "StarknetToken", int(1e18), owner.starknet_contract.address
        )
    )["address"]
    starknetToken = get_contract_starknet("StarknetToken", address=address)
    return starknetToken


@pytest_asyncio.fixture()
async def dualVmToken(starknetToken, deploy_contract, invoke, owner):
    kakarot = get_deployments()["kakarot"]
    dualVmToken = await deploy_contract(
        "CairoPrecompiles",
        "DualVmToken",
        kakarot["address"],
        starknetToken.address,
        caller_eoa=owner.starknet_contract,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(dualVmToken.address, 16),
        True,
    )
    return dualVmToken


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestDualVmToken:
    class TestMetadata:
        async def test_should_return_name(
            self, starknetToken, dualVmToken, get_contract, invoke
        ):
            (name_starknet,) = await starknetToken.functions["name"].call()
            name_evm = await dualVmToken.name()
            assert name_starknet == name_evm

        async def test_should_return_symbol(
            self, starknetToken, dualVmToken, get_contract, invoke
        ):
            (symbol_starknet,) = await starknetToken.functions["symbol"].call()
            symbol_evm = await dualVmToken.symbol()
            assert symbol_starknet == symbol_evm

        async def test_should_return_decimals(
            self, starknetToken, dualVmToken, get_contract, invoke
        ):
            (decimals_starknet,) = await starknetToken.functions["decimals"].call()
            decimals_evm = await dualVmToken.decimals()
            assert decimals_starknet == decimals_evm

    class TestAccounting:

        async def test_should_return_total_supply(
            self, starknetToken, dualVmToken, get_contract, invoke
        ):
            (total_supply_starknet,) = await starknetToken.functions[
                "total_supply"
            ].call()
            total_supply_evm = await dualVmToken.totalSupply()
            assert total_supply_starknet == total_supply_evm

        async def test_should_return_balance_of(
            self, starknetToken, dualVmToken, get_contract, invoke, owner
        ):
            (balance_owner_starknet,) = await starknetToken.functions[
                "balance_of"
            ].call(owner.starknet_contract.address)
            balance_owner_evm = await dualVmToken.balanceOf(owner.address)
            assert balance_owner_starknet == balance_owner_evm

    class TestActions:
        async def test_should_transfer(
            self, starknetToken, dualVmToken, get_contract, invoke, owner, other
        ):
            amount = 1
            balance_owner_before = await dualVmToken.balanceOf(owner.address)
            balance_other_before = await dualVmToken.balanceOf(other.address)
            await dualVmToken.transfer(other.address, amount)
            balance_owner_after = await dualVmToken.balanceOf(owner.address)
            balance_other_after = await dualVmToken.balanceOf(other.address)

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        async def test_should_approve(
            self, starknetToken, dualVmToken, get_contract, invoke, owner, other
        ):
            amount = 1
            allowance_before = await dualVmToken.allowance(owner.address, other.address)
            await dualVmToken.approve(other.address, amount)
            allowance_after = await dualVmToken.allowance(owner.address, other.address)
            assert allowance_after == allowance_before + amount

        async def test_should_transfer_from(
            self, starknetToken, dualVmToken, get_contract, invoke, owner, other
        ):
            amount = 1
            balance_owner_before = await dualVmToken.balanceOf(owner.address)
            balance_other_before = await dualVmToken.balanceOf(other.address)
            await dualVmToken.approve(other.address, amount)
            await dualVmToken.transferFrom(
                owner.address, other.address, amount, caller_eoa=other.starknet_contract
            )
            balance_owner_after = await dualVmToken.balanceOf(owner.address)
            balance_other_after = await dualVmToken.balanceOf(other.address)

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after
