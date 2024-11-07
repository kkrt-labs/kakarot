import pytest
import pytest_asyncio
from eth_abi import encode

from kakarot_scripts.utils.kakarot import deploy, eth_send_transaction
from kakarot_scripts.utils.starknet import get_contract, invoke
from tests.utils.errors import cairo_error

CALL_CAIRO_PRECOMPILE = 0x75004


@pytest_asyncio.fixture(scope="module")
async def cairo_counter(max_fee, deployer):
    cairo_counter = get_contract("Counter", provider=deployer)

    yield cairo_counter

    await invoke("Counter", "set_counter", 0)


@pytest_asyncio.fixture(scope="module")
async def cairo_counter_caller(cairo_counter):
    return await deploy(
        "CairoPrecompiles",
        "CallCairoPrecompileTest",
        cairo_counter.address,
    )


@pytest_asyncio.fixture(scope="module")
async def kakarot_reentrancy(kakarot):
    return await deploy(
        "CairoPrecompiles",
        "KakarotReentrancyTest",
        kakarot.address,
    )


@pytest_asyncio.fixture(scope="module")
async def eth_call_calldata_fixture(kakarot, new_eoa):
    eoa = await new_eoa()
    return (
        kakarot.functions["eth_call"]
        .prepare_call(
            nonce=0,
            origin=int(eoa.address, 16),
            to={"is_some": 1, "value": 0xDEAD},
            gas_limit=41000,
            gas_price=1_000,
            value=1_000,
            data=bytes(),
            access_list=[],
        )
        .calldata
    )


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        async def test_should_increase_counter(self, cairo_counter, owner):
            prev_count = (await cairo_counter.functions["get"].call()).count

            call = cairo_counter.functions["inc"].prepare_call()
            tx_data = encode(
                ["uint256", "uint256", "uint256[]"],
                [int(call.to_addr), int(call.selector), call.calldata],
            )

            await eth_send_transaction(
                to=f"0x{CALL_CAIRO_PRECOMPILE:040x}",
                gas=41000,
                data=tx_data,
                value=0,
                caller_eoa=owner.starknet_contract,
            )

            new_count = (await cairo_counter.functions["get"].call()).count
            expected_count = prev_count + 1
            assert new_count == expected_count

        async def test_should_increase_counter_from_solidity(
            self, cairo_counter, cairo_counter_caller
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count
            await cairo_counter_caller.incrementCairoCounter()
            new_count = (await cairo_counter.functions["get"].call()).count
            expected_increment = 1
            assert new_count == prev_count + expected_increment

        async def test_should_fail_when_called_with_delegatecall(
            self, cairo_counter_caller
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await cairo_counter_caller.incrementCairoCounterDelegatecall()

        async def test_should_fail_when_called_with_callcode(
            self, cairo_counter_caller
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await cairo_counter_caller.incrementCairoCounterCallcode()

    class TestReentrancyKakarot:
        async def test_should_fail_when_reentrancy_cairo_call(
            self, kakarot, kakarot_reentrancy, new_eoa, eth_call_calldata_fixture
        ):
            with cairo_error("ReentrancyGuard: reentrant call"):
                await kakarot_reentrancy.staticcallKakarot(
                    "eth_call", eth_call_calldata_fixture
                )

        async def test_should_fail_when_reentrancy_cairo_call_whitelisted(
            self, kakarot, kakarot_reentrancy, new_eoa, eth_call_calldata_fixture
        ):
            # Setup for whitelisted precompile
            await invoke(
                "kakarot",
                "set_authorized_cairo_precompile_caller",
                int(kakarot_reentrancy.address, 16),
                True,
            )

            with cairo_error("ReentrancyGuard: reentrant call"):
                await kakarot_reentrancy.whitelistedStaticcallKakarot(
                    "eth_call", eth_call_calldata_fixture
                )

            # TearDown
            await invoke(
                "kakarot",
                "set_authorized_cairo_precompile_caller",
                int(kakarot_reentrancy.address, 16),
                False,
            )
