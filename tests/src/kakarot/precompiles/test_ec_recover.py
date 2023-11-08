import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ec_recover(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/precompiles/test_ec_recover.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
@pytest.mark.EC_RECOVER
class TestEcRecover:
    async def test_should_fail_when_input_len_is_not_128(self, ec_recover):
        (output,) = (
            await ec_recover.test_should_fail_when_input_len_is_not_128().call()
        ).result
        assert bytes(output).decode() == "Precompile: wrong input_len"

    async def test_should_fail_when_recovery_identifier_is_neither_27_nor_28(
        self, ec_recover
    ):
        (output,) = (
            await ec_recover.test_should_fail_when_recovery_identifier_is_neither_27_nor_28().call()
        ).result
        assert bytes(output).decode() == "Precompile: flag error"

    async def test_should_return_evm_address_in_bytes32(self, ec_recover):
        await ec_recover.test_should_return_evm_address_in_bytes32().call()

    async def test_should_return_evm_address_for_playground_example(self, ec_recover):
        await ec_recover.test_should_return_evm_address_for_playground_example().call()
