import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ecadd(
    starknet: Starknet, blockhashes: dict, blockhash_registry: StarknetContract
):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_ecadd.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestEcAdd:
    @pytest.mark.parametrize(
        "calldata_len",
        [128],
        ids=["calldata_len128"],
    )
    async def test_ecadd(self, ecadd, calldata_len):
        random.seed(0)
        calldata = [random.randint(0, 255) for _ in range((calldata_len))]
        
        await ecadd.test__ecadd_impl(calldata=calldata).call()
