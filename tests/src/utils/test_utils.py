import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def helpers(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/utils/test_utils.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
@pytest.mark.Utils
class TestHelpers:
    async def test__bytes_i_to_uint256(self, helpers):
        await helpers.test__bytes_i_to_uint256().call()

    async def test__bytes_to_bytes4_array(self, helpers):
        await helpers.test__bytes_to_bytes4_array().call()

    async def test__bytes4_array_to_bytes(self, helpers):
        await helpers.test__bytes4_array_to_bytes().call()
