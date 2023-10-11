import os

import pytest

from tests.utils.errors import kakarot_error


@pytest.mark.asyncio
@pytest.mark.Counter
class TestCounter:
    class TestCount:
        async def test_should_return_0_after_deployment(
            self, deploy_solidity_contract, owner
        ):
            counter = await deploy_solidity_contract(
                "PlainOpcodes",
                "Counter",
                caller_eoa=owner.starknet_contract,
            )
            assert await counter.count() == 0

    class TestInc:
        async def test_should_increase_count(self, counter, owner):
            await counter.reset(caller_eoa=owner)
            await counter.inc(caller_eoa=owner)
            assert await counter.count() == 1

    class TestDec:
        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_raise_from_modifier_when_count_is_0(self, counter, owner):
            await counter.reset(caller_eoa=owner)
            with kakarot_error("count should be strictly greater than 0"):
                await counter.dec(caller_eoa=owner)

        @pytest.mark.xfail(
            reason="https://github.com/kkrt-labs/kakarot/issues/683",
        )
        async def test_should_raise_from_vm_when_count_is_0(self, counter, owner):
            await counter.reset(caller_eoa=owner)
            with kakarot_error():
                await counter.decUnchecked(caller_eoa=owner)

        async def test_should_decrease_count(self, counter, owner):
            await counter.reset(caller_eoa=owner)
            await counter.inc(caller_eoa=owner)
            await counter.dec(caller_eoa=owner)
            assert await counter.count() == 0

        async def test_should_decrease_count_unchecked(self, counter, owner):
            await counter.reset(caller_eoa=owner)
            await counter.inc(caller_eoa=owner)
            await counter.decUnchecked(caller_eoa=owner)
            assert await counter.count() == 0

        async def test_should_decrease_count_in_place(self, counter, owner):
            await counter.reset(caller_eoa=owner)
            await counter.inc(caller_eoa=owner)
            await counter.decInPlace(caller_eoa=owner)
            assert await counter.count() == 0

    class TestReset:
        async def test_should_set_count_to_0(self, counter, owner):
            await counter.inc(caller_eoa=owner)
            await counter.reset(caller_eoa=owner)
            assert await counter.count() == 0

    class TestDeploymentWithValue:
        async def test_deployment_with_value_should_fail(
            self, deploy_solidity_contract
        ):
            with kakarot_error():
                await deploy_solidity_contract("PlainOpcodes", "Counter", value=1)

    class TestLoops:
        @pytest.mark.parametrize("iterations", [0, 50, 100])
        async def test_should_set_counter_to_iterations_with_for_loop(
            self, counter, owner, iterations
        ):
            await counter.incForLoop(iterations, caller_eoa=owner)
            assert await counter.count() == iterations

        @pytest.mark.parametrize("iterations", [0, 50, 200])
        async def test_should_set_counter_to_iterations_with_while_loop(
            self, counter, owner, iterations
        ):
            await counter.incWhileLoop(iterations, caller_eoa=owner)
            assert await counter.count() == iterations
