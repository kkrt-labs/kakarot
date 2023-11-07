import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def precompiles(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/precompiles/test_precompiles.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestPrecompiles:
    class TestRun:
        @pytest.mark.parametrize(
            "address,error_message",
            [
                (0x0, "Kakarot: UnknownPrecompile 0"),
                (0x2, "Kakarot: NotImplementedPrecompile 2"),
                (0x5, "Kakarot: NotImplementedPrecompile 5"),
                (0x6, "Kakarot: NotImplementedPrecompile 6"),
                (0x7, "Kakarot: NotImplementedPrecompile 7"),
                (0x8, "Kakarot: NotImplementedPrecompile 8"),
            ],
        )
        async def test__precompiles_run(self, precompiles, address, error_message):
            return_data, reverted = (
                await precompiles.test__precompiles_run(address=address).call()
            ).result
            assert bytes(return_data).decode() == error_message
            assert reverted

    class TestIsPrecompile:
        @pytest.mark.parametrize("address", range(1, 11))
        async def test__is_precompile_should_return_true_up_to_9(
            self, precompiles, address
        ):
            is_precompile = (
                await precompiles.test__is_precompile(address).call()
            ).result[0]
            assert is_precompile == (address <= 0x9)
