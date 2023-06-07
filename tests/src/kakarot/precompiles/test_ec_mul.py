import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ec_mul(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/precompiles/test_ec_mul.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
@pytest.mark.EC_MUL
class TestEcMul:
    async def test_ec_mul(self, ec_mul):
        await ec_mul.test__ecmul_impl().call()
