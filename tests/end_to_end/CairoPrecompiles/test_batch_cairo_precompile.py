from typing import Any, List, Tuple

import pytest
import pytest_asyncio
from eth_abi import encode
from eth_utils import keccak
from hypothesis import given, settings
from hypothesis import strategies as st

from kakarot_scripts.utils.kakarot import deploy, eth_send_transaction
from kakarot_scripts.utils.starknet import get_contract, wait_for_transaction
from tests.utils.errors import cairo_error

EVM_MULTICALLCAIRO_SELECTOR = keccak(
    text="call_contract(uint256,uint256,uint256,uint256[])"
)[:4]


@pytest_asyncio.fixture(scope="module")
async def cairo_counter(max_fee, deployer):
    cairo_counter = get_contract("Counter", provider=deployer)

    yield cairo_counter

    tx = await cairo_counter.functions["set_counter"].invoke_v1(0, max_fee=max_fee)
    await wait_for_transaction(tx.hash)


@pytest_asyncio.fixture(scope="module")
async def multicall_cairo_counter_caller(owner, cairo_counter):
    caller_contract = await deploy(
        "CairoPrecompiles",
        "MulticallCairoCounterCaller",
        cairo_counter.address,
        caller_eoa=owner.starknet_contract,
    )
    return caller_contract


def encode_starknet_call(call) -> bytes:
    return encode(
        ["uint256", "uint256", "uint256[]"],
        [call.to_addr, call.selector, call.calldata],
    )


def prepare_transaction_data(calls: List[Tuple[Any, str, List[Any]]]) -> str:
    encoded_calls = b"".join(
        encode_starknet_call(entrypoint.prepare_call(*calldata))
        for entrypoint, calldata in calls
    )
    return f"{len(calls):064x}" + encoded_calls.hex()


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        @given(calls_per_batch=st.integers(min_value=0, max_value=100))
        @settings(max_examples=5)
        async def test_should_increase_counter_in_batches(
            self, cairo_counter, owner, calls_per_batch
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count

            calls = [
                (cairo_counter.functions["inc"], []) for _ in range(calls_per_batch)
            ]
            tx_data = prepare_transaction_data(calls)

            await eth_send_transaction(
                to=f"0x{0x75003:040x}",
                gas=21000 + 20000 * calls_per_batch,
                data=tx_data,
                value=0,
            )

            new_count = (await cairo_counter.functions["get"].call()).count
            assert (
                new_count == prev_count + calls_per_batch
            ), f"Expected count to increase by {calls_per_batch}, but it increased by {new_count - prev_count}"

        async def test_should_set_and_increase_counter_in_batch(
            self, cairo_counter, owner
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count
            new_counter = prev_count * 2 + 100

            calls = [
                (cairo_counter.functions["set_counter"], [new_counter]),
                (cairo_counter.functions["inc"], []),
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
            assert (
                new_count == expected_count
            ), f"Expected count to be {expected_count}, but it is {new_count}"

        async def test_should_increase_counter_single_call_from_solidity(
            self, cairo_counter, multicall_cairo_counter_caller
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count
            await multicall_cairo_counter_caller.incrementCairoCounter()
            new_count = (await cairo_counter.functions["get"].call()).count
            expected_increment = 1
            assert (
                new_count == prev_count + expected_increment
            ), f"Expected count to increase by {expected_increment}, but it increased by {new_count - prev_count}"

        async def test_should_increase_counter_in_multicall_from_solidity(
            self, cairo_counter, multicall_cairo_counter_caller
        ):
            expected_increment = 5
            prev_count = (await cairo_counter.functions["get"].call()).count
            await multicall_cairo_counter_caller.incrementCairoCounterBatch(
                expected_increment
            )
            new_count = (await cairo_counter.functions["get"].call()).count
            assert (
                new_count == prev_count + expected_increment
            ), f"Expected count to increase by {expected_increment}, but it increased by {new_count - prev_count}"

        async def test_should_fail_when_called_with_delegatecall(
            self, multicall_cairo_counter_caller
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await multicall_cairo_counter_caller.incrementCairoCounterDelegatecall()

        async def test_should_fail_when_called_with_callcode(
            self, multicall_cairo_counter_caller, cairo_counter
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await multicall_cairo_counter_caller.incrementCairoCounterCallcode()

        # TODO
        # async def test_should_fail_when_data_len_too_big(
        #     self, multicall_cairo_counter_caller
        # ):
        #     with cairo_error(""):
        #         # Create a large data payload that exceeds 2^32 bytes
        #         large_data = b"0" * (2**32 + 1)
