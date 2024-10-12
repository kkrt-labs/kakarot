import pytest
import pytest_asyncio
from eth_abi import encode
from eth_utils import keccak
from hypothesis import given, settings
from hypothesis import strategies as st
from starknet_py.hash.selector import get_selector_from_name

from kakarot_scripts.utils.kakarot import deploy, eth_send_transaction
from kakarot_scripts.utils.starknet import get_contract, wait_for_transaction
from kakarot_scripts.utils.uint256 import int_to_uint256
from tests.utils.errors import cairo_error


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


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        @given(
            calls_per_batch=st.integers(min_value=0, max_value=100),
        )
        @settings(max_examples=5)
        async def test_should_increase_counter_in_batches(
            self, cairo_counter, owner, calls_per_batch
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count

            evm_call_selector = keccak(text="call_contract(uint256,uint256,uint256[])")[
                :4
            ]

            # Starknet call to perform in the batch
            starknet_address = cairo_counter.address
            starknet_selector = get_selector_from_name("inc")
            data = []
            encoded_starknet_call = encode(
                ["uint256", "uint256", "uint256[]"],
                [starknet_address, starknet_selector, data],
            )

            tx_data = (
                evm_call_selector.hex()
                + f"{calls_per_batch:08x}"
                + encoded_starknet_call.hex() * calls_per_batch
            )
            await eth_send_transaction(
                to=f"0x{0x75003:040x}",
                gas=21000
                + 20000
                * calls_per_batch,  # Gas is 21k base + 10k per call + calldata cost
                data=tx_data,
                value=0,
                caller_eoa=owner.starknet_contract,
            )

            new_count = (await cairo_counter.functions["get"].call()).count
            expected_increment = calls_per_batch
            assert (
                new_count == prev_count + expected_increment
            ), f"Expected count to increase by {expected_increment}, but it increased by {new_count - prev_count}"

        async def test_should_set_and_increase_counter_in_batch(
            self, cairo_counter, owner
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count

            evm_call_selector = keccak(text="call_contract(uint256,uint256,uint256[])")[
                :4
            ]
            starknet_address = cairo_counter.address

            # 1st starknet call to perform in the batch
            starknet_selector = get_selector_from_name("set_counter")
            data = list(int_to_uint256(prev_count * 2 + 100))
            encoded_starknet_call_1 = encode(
                ["uint256", "uint256", "uint256[]"],
                [starknet_address, starknet_selector, data],
            )

            # 2nd starknet call to perform in the batch
            starknet_selector = get_selector_from_name("inc")
            data = []
            encoded_starknet_call_2 = encode(
                ["uint256", "uint256", "uint256[]"],
                [starknet_address, starknet_selector, data],
            )

            encoded_starknet_calls = encoded_starknet_call_1 + encoded_starknet_call_2
            calls_per_batch = 2

            tx_data = (
                evm_call_selector.hex()
                + f"{calls_per_batch:08x}"
                + encoded_starknet_calls.hex()
            )
            await eth_send_transaction(
                to=f"0x{0x75003:040x}",
                gas=21000
                + 20000
                * calls_per_batch,  # Gas is 21k base + 10k per call + calldata cost
                data=tx_data,
                value=0,
                caller_eoa=owner.starknet_contract,
            )

            new_count = (await cairo_counter.functions["get"].call()).count
            expected_count = (prev_count * 2 + 100) + 1
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
            expected_increment = 2
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
