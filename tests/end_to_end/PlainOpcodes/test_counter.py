import pytest

from kakarot_scripts.utils.kakarot import deploy
from tests.utils.errors import evm_error


@pytest.mark.asyncio(scope="package")
@pytest.mark.Counter
class TestCounter:
    class TestCount:
        async def test_should_return_0_after_deployment(self, owner):
            counter = await deploy(
                "PlainOpcodes", "Counter", caller_eoa=owner.starknet_contract
            )
            assert await counter.count() == 0

    class TestInc:
        async def test_should_increase_count(self, counter):
            await counter.reset()
            await counter.inc()
            assert await counter.count() == 1

    class TestDec:
        async def test_should_raise_from_modifier_when_count_is_0(self, counter):
            await counter.reset()
            with evm_error("count should be strictly greater than 0"):
                await counter.decWithModifier()

        async def test_should_return_uint256_max(self, counter):
            await counter.reset()
            await counter.decUnchecked()
            assert await counter.count() == 2**256 - 1

        async def test_should_revert_when_count_zero(self, counter):
            await counter.reset()
            with evm_error():
                await counter.dec()

        async def test_should_decrease_count(self, counter):
            await counter.reset()
            await counter.inc()
            await counter.dec()
            assert await counter.count() == 0

        async def test_should_decrease_count_unchecked(self, counter):
            await counter.reset()
            await counter.inc()
            await counter.decUnchecked()
            assert await counter.count() == 0

        async def test_should_decrease_count_in_place(self, counter):
            await counter.reset()
            await counter.inc()
            await counter.decInPlace()
            assert await counter.count() == 0

    class TestReset:
        async def test_should_set_count_to_0(self, counter):
            await counter.inc()
            await counter.reset()
            assert await counter.count() == 0

    class TestDeploymentWithValue:
        async def test_deployment_with_value_should_fail(self):
            with evm_error():
                await deploy("PlainOpcodes", "Counter", value=1)

    class TestLoops:
        @pytest.mark.parametrize("iterations", [0, 50, 100])
        async def test_should_set_counter_to_iterations_with_for_loop(
            self, counter, iterations
        ):
            await counter.incForLoop(iterations)
            assert await counter.count() == iterations

        @pytest.mark.parametrize("iterations", [0, 50, 186])
        async def test_should_set_counter_to_iterations_with_while_loop(
            self, counter, iterations
        ):
            await counter.incWhileLoop(iterations)
            assert await counter.count() == iterations
