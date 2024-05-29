import pytest
import pytest_asyncio

from kakarot_scripts.utils.starknet import get_deployments, wait_for_transaction


@pytest.fixture(autouse=True)
async def cleanup(get_contract, max_fee):
    yield
    cairo_counter = get_contract("Counter")
    tx = await cairo_counter.functions["set_counter"].invoke_v1(0, max_fee=max_fee)
    await wait_for_transaction(tx.hash)


@pytest_asyncio.fixture(scope="module")
async def cairo_counter_caller(deploy_contract, owner):
    cairo_counter_address = get_deployments()["Counter"]["address"]
    return await deploy_contract(
        "CairoPrecompiles",
        "CairoCounterCaller",
        cairo_counter_address,
        caller_eoa=owner.starknet_contract,
    )


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        async def test_should_get_cairo_counter(
            self, get_contract, cairo_counter_caller, max_fee
        ):
            cairo_counter = get_contract("Counter")
            cairo_count = (await cairo_counter.functions["get"].call()).count
            await cairo_counter.functions["inc"].invoke_v1(max_fee=max_fee)
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
