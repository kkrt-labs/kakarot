import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy, get_eoa
from kakarot_scripts.utils.starknet import get_contract, invoke, wait_for_transaction
from tests.utils.errors import evm_error


@pytest_asyncio.fixture()
async def cairo_counter(max_fee, deployer):
    cairo_counter = get_contract("Counter", provider=deployer)

    yield cairo_counter

    tx = await cairo_counter.functions["set_counter"].invoke_v1(0, max_fee=max_fee)
    await wait_for_transaction(tx.hash)


@pytest_asyncio.fixture()
async def cairo_counter_caller(owner, cairo_counter):
    caller_contract = await deploy(
        "CairoPrecompiles",
        "CairoCounterCaller",
        cairo_counter.address,
        caller_eoa=owner.starknet_contract,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(caller_contract.address, 16),
        True,
    )
    return caller_contract


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        async def test_should_get_cairo_counter(
            self, cairo_counter, cairo_counter_caller
        ):
            await invoke("Counter", "inc")
            cairo_count = (await cairo_counter.functions["get"].call()).count
            evm_count = await cairo_counter_caller.getCairoCounter()
            assert evm_count == cairo_count == 1

        async def test_should_increase_cairo_counter(
            self, cairo_counter, cairo_counter_caller, max_fee
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count
            await cairo_counter_caller.incrementCairoCounter()
            new_count = (await cairo_counter.functions["get"].call()).count
            assert new_count == prev_count + 1

        @pytest.mark.parametrize("count", [0, 1, 2**128 - 1, 2**128, 2**256 - 1])
        async def test_should_set_cairo_counter(
            self, cairo_counter, cairo_counter_caller, owner, count
        ):
            await cairo_counter_caller.setCairoCounter(count)
            new_count = (await cairo_counter.functions["get"].call()).count

            assert new_count == count

        async def test_should_fail_precompile_caller_not_whitelisted(
            self, cairo_counter, max_fee
        ):
            cairo_counter_caller = await deploy(
                "CairoPrecompiles", "CairoCounterCaller", cairo_counter.address
            )
            with evm_error("CairoLib: call_contract failed"):
                await cairo_counter_caller.incrementCairoCounter()

        async def test_last_caller_address_should_be_eoa(self, cairo_counter_caller):
            eoa = await get_eoa()
            await cairo_counter_caller.incrementCairoCounter(caller_eoa=eoa)
            last_caller_address = await cairo_counter_caller.getLastCaller()
            assert last_caller_address == eoa.address
