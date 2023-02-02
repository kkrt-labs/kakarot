import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error


@pytest_asyncio.fixture(scope="module")
async def precompiles(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_precompiles.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestPrecompiles:
    class TestRun:
        async def test__run_should_return_a_stopped_execution_context(
            self, precompiles
        ):
            # we choose datacopy precompile address
            data_copy_address = 0x4
            await precompiles.test__run_should_return_a_stopped_execution_context(
                address=data_copy_address
            ).call()

    class TestIsPrecompile:
        @pytest.mark.parametrize("address", range(1, 11))
        async def test__is_precompile_should_return_true_up_to_9(
            self, precompiles, address
        ):
            is_precompile = (await precompiles.test__is_precompile(address).call()).result[0]
            assert is_precompile == (address <= 0x9)

    class TestNotImplementedPrecompile:
        async def test__not_implemented_precompile_should_raise_with_detailed_error_message(
            self, precompiles
        ):
            # we choose an address of a non implemented precompile and we check that the Non Implemented Precompile error msg appear.
            not_impl_precompile_address = 0x8
            with kakarot_error(
                f"Kakarot: NotImplementedPrecompile {not_impl_precompile_address}"
            ):
                await precompiles.test__precompiles_should_throw_on_out_of_bounds(
                    address=not_impl_precompile_address
                ).call()

    class TestExecPrecompile:
        async def test__exec_precompiles_should_throw_non_implemented_precompile(
            self, precompiles
        ):
            # we choose an address of a non implemented precompile and we check that the Non Implemented Precompile error msg appear.
            not_impl_precompile_address = 0x9 + 1
            with kakarot_error():
                await precompiles.test__exec_precompiles_should_throw_non_implemented_precompile_message(
                    address=not_impl_precompile_address
                ).call()
