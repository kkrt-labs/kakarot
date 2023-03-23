import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ec_mul(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/src/kakarot/precompiles/test_ec_mul.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.EC_MUL
class TestEcMul:
    async def test_ec_mul(self, ec_mul):

        await ec_mul.test__ecmul_impl().call()
