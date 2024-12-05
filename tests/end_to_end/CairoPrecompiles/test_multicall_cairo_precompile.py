from typing import Any, List, Tuple

import pytest
import pytest_asyncio
from eth_abi import encode
from hypothesis import assume, given, settings
from hypothesis import strategies as st
from starkware.cairo.lang.cairo_constants import DEFAULT_PRIME

from kakarot_scripts.utils.kakarot import deploy, eth_send_transaction
from kakarot_scripts.utils.starknet import get_contract, invoke
from tests.utils.errors import cairo_error, evm_error


@pytest_asyncio.fixture(scope="module")
async def cairo_counter(deployer):
    cairo_counter = get_contract("Counter", provider=deployer)

    yield cairo_counter

    await invoke("Counter", "set_counter", 0)


@pytest_asyncio.fixture(scope="module")
async def multicall_cairo_counter_caller(cairo_counter):
    caller_contract = await deploy(
        "CairoPrecompiles",
        "MulticallCairoPrecompileTest",
        cairo_counter.address,
    )
    return caller_contract


def prepare_transaction_data(calls: List[Tuple[Any, List[Any]]]) -> str:
    encoded_calls = b"".join(
        encode(
            ["uint256", "uint256", "uint256[]"],
            [int(call.to_addr), int(call.selector), call.calldata],
        )
        for call in calls
    )

    return f"{len(calls):064x}" + encoded_calls.hex()


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        @given(calls_per_batch=st.integers(min_value=0, max_value=100))
        @settings(max_examples=5)
        async def test_should_increase_counter_in_batches(
            self, cairo_counter, calls_per_batch
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count

            calls = [
                cairo_counter.functions["inc"].prepare_call()
                for _ in range(calls_per_batch)
            ]
            tx_data = prepare_transaction_data(calls)

            await eth_send_transaction(
                to=f"0x{0x75003:040x}",
                gas=21000 + 20000 * calls_per_batch,
                data=tx_data,
                value=0,
            )

            new_count = (await cairo_counter.functions["get"].call()).count
            assert new_count == prev_count + calls_per_batch

        async def test_should_set_and_increase_counter_in_batch(
            self, cairo_counter, owner
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count
            new_counter = prev_count * 2 + 100

            calls = [
                cairo_counter.functions["set_counter"].prepare_call(new_counter),
                cairo_counter.functions["inc"].prepare_call(),
            ]
            tx_data = prepare_transaction_data(calls)

            await eth_send_transaction(
                to=f"0x{0x75003:040x}",
                gas=21000 + 20000 * len(calls),
                data=tx_data,
                value=0,
                caller_eoa=owner.starknet_contract,
            )

            new_count = (await cairo_counter.functions["get"].call()).count
            expected_count = new_counter + 1
            assert new_count == expected_count

        @given(wrong_nb_calls=st.integers(min_value=0, max_value=DEFAULT_PRIME - 1))
        async def test_should_fail_when_number_of_calls_mismatch_actual_calls(
            self, cairo_counter, owner, wrong_nb_calls
        ):
            assume(wrong_nb_calls != 2)
            calls = [
                cairo_counter.functions["set_counter"].prepare_call(1),
                cairo_counter.functions["inc"].prepare_call(),
            ]
            tx_data = prepare_transaction_data(calls)
            # modify the number of calls to be different than the actual calls
            tx_data = f"{wrong_nb_calls:064x}" + tx_data[64:]

            with cairo_error(
                "Number of executed calls does not match precompile input"
            ):
                await eth_send_transaction(
                    to=f"0x{0x75003:040x}",
                    gas=21000 + 20000 * (len(calls)),
                    data=tx_data,
                    value=0,
                    caller_eoa=owner.starknet_contract,
                )

        async def test_should_increase_counter_single_call_from_solidity(
            self, cairo_counter, multicall_cairo_counter_caller
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count
            await multicall_cairo_counter_caller.incrementCairoCounter()
            new_count = (await cairo_counter.functions["get"].call()).count
            expected_increment = 1
            assert new_count == prev_count + expected_increment

        async def test_should_increase_counter_in_multicall_from_solidity(
            self, cairo_counter, multicall_cairo_counter_caller
        ):
            expected_increment = 5
            prev_count = (await cairo_counter.functions["get"].call()).count
            await multicall_cairo_counter_caller.incrementCairoCounterBatch(
                expected_increment
            )
            new_count = (await cairo_counter.functions["get"].call()).count
            assert new_count == prev_count + expected_increment

        async def test_should_fail_when_called_with_delegatecall(
            self, multicall_cairo_counter_caller
        ):
            with evm_error("CairoLib: call_contract failed with"):
                await multicall_cairo_counter_caller.incrementCairoCounterDelegatecall()

        async def test_should_fail_when_called_with_callcode(
            self, multicall_cairo_counter_caller
        ):
            with evm_error("CairoLib: call_contract failed with"):
                await multicall_cairo_counter_caller.incrementCairoCounterCallcode()
