import pytest
import pytest_asyncio


@pytest_asyncio.fixture
async def helpers(starknet):
    return await starknet.deploy(
        source="./tests/unit/src/utils/test_utils.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
@pytest.mark.Utils
class TestHelpers:
    async def test__bytes_i_to_uint256(self, helpers):
        await helpers.test__bytes_i_to_uint256().call()

    async def test__bytes_to_bytes4_array(self, helpers):
        await helpers.test__bytes_to_bytes4_array().call()

    async def test__bytes4_array_to_bytes(self, helpers):
        await helpers.test__bytes4_array_to_bytes().call()
