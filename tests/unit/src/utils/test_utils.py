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
class TestStack:
    async def test__bytes_i_to_uint256(self, helpers):
        await helpers.test__bytes_i_to_uint256().call()


@pytest.mark.asyncio
@pytest.mark.Utils
class TestHelpers:
    async def test__bytes_to_words_32bit_array(self, helpers):
        await helpers.test__bytes_to_words_32bit_array().call()

    async def test__words_32bit_to_bytes_array(self, helpers):
        await helpers.test__words_32bit_to_bytes_array().call()
