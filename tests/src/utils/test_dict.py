import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture
async def dict_(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/utils/test_dict.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestDict:
    class TestDictKeys:
        async def test_should_return_keys(self, dict_):
            await dict_.test__dict_keys__should_return_keys().call()

    class TestDefaultDictCopy:
        async def test_should_return_copied_dict(self, dict_):
            await dict_.test__default_dict_copy__should_return_copied_dict().call()
