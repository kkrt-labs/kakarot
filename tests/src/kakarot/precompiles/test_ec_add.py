import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ec_add(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/precompiles/test_ec_add.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
@pytest.mark.EC_ADD
class TestEcAdd:
    @pytest.mark.parametrize(
        "calldata_len",
        [128],
        ids=["calldata_len128"],
    )
    async def test_ecadd(self, ec_add, calldata_len):
        random.seed(0)
        calldata = [random.randint(0, 255) for _ in range((calldata_len))]

        await ec_add.test__ecadd_impl(calldata=calldata).call()
