import re

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ec_recover(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_ec_recover.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.EC_RECOVER
class TestEcRecover:
    async def test_should_fail_when_input_len_is_not_128(self, ec_recover):
        with pytest.raises(Exception) as e:
            await ec_recover.test_should_fail_when_input_len_is_not_128().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert (
            message
            == "EcRecover: received wrong number of bytes in input: 0 instead of 4*32"
        )

    async def test_should_fail_when_recovery_identifier_is_neither_27_nor_28(
        self, ec_recover
    ):
        with pytest.raises(Exception) as e:
            await ec_recover.test_should_fail_when_recovery_identifier_is_neither_27_nor_28().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == f"EcRecover: Recovery identifier should be either 27 or 28"

    async def test_should_return_eth_address_in_bytes32(self, ec_recover):
        await ec_recover.test_should_return_eth_address_in_bytes32().call()

    async def test_should_return_eth_address_for_playground_example(self, ec_recover):
        await ec_recover.test_should_return_eth_address_for_playground_example().call()
