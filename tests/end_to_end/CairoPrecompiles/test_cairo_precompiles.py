import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import get_eoa
from kakarot_scripts.utils.starknet import get_deployments, wait_for_transaction
from tests.utils.errors import evm_error


@pytest_asyncio.fixture(autouse=True)
async def cleanup(get_contract, max_fee):
    yield
    cairo_counter = get_contract("Counter")
    tx = await cairo_counter.functions["set_counter"].invoke_v1(0, max_fee=max_fee)
    await wait_for_transaction(tx.hash)


@pytest_asyncio.fixture()
async def cairo_counter_caller(deploy_contract, invoke, owner):
    cairo_counter_address = get_deployments()["Counter"]["address"]
    counter_contract = await deploy_contract(
        "CairoPrecompiles",
        "CairoCounterCaller",
        cairo_counter_address,
        caller_eoa=owner.starknet_contract,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(counter_contract.address, 16),
        True,
    )
    return counter_contract


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        async def test_should_get_cairo_counter(
            self, get_contract, cairo_counter_caller, invoke
        ):
            cairo_counter = get_contract("Counter")
            cairo_count = (await cairo_counter.functions["get"].call()).count
            await invoke("Counter", "inc")
            evm_count = await cairo_counter_caller.getCairoCounter()
            assert evm_count == cairo_count + 1

        async def test_should_increase_cairo_counter(
            self, get_contract, cairo_counter_caller, max_fee
        ):
            cairo_counter = get_contract("Counter")
            prev_count = (await cairo_counter.functions["get"].call()).count
            await cairo_counter_caller.incrementCairoCounter()
            new_count = (await cairo_counter.functions["get"].call()).count
            assert new_count == prev_count + 1

        @pytest.mark.parametrize("count", [0, 1, 2**128 - 1, 2**128, 2**256 - 1])
        async def test_should_set_cairo_counter(
            self, get_contract, cairo_counter_caller, owner, count
        ):
            cairo_counter = get_contract("Counter")
            await cairo_counter_caller.setCairoCounter(count)
            new_count = (await cairo_counter.functions["get"].call()).count

            assert new_count == count

        async def test_should_fail_precompile_caller_not_whitelisted(
            self, deploy_contract, get_contract, max_fee
        ):
            cairo_counter = get_contract("Counter")
            cairo_counter_caller = await deploy_contract(
                "CairoPrecompiles", "CairoCounterCaller", cairo_counter.address
            )
            with evm_error("CairoLib: call_contract failed"):
                await cairo_counter_caller.incrementCairoCounter(max_fee=max_fee)

        async def test_last_caller_address_should_be_eoa(
            self, get_contract, cairo_counter_caller
        ):
            eoa = await get_eoa()
            await cairo_counter_caller.incrementCairoCounter(caller_eoa=eoa)
            last_caller_address = await cairo_counter_caller.getLastCaller()
            assert last_caller_address == eoa.address
