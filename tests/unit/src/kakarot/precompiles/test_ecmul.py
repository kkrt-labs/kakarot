import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ecmul(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_ecmul.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.EC_MUL
class TestEcMul:
    async def test_ecmul(self, ecmul):

        await ecmul.test__ecmul_impl().call()
