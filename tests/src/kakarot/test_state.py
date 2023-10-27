import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture
async def state(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_state.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestState:
    class TestInit:
        async def test_should_return_state_with_default_dicts(self, state):
            await state.test__init__should_return_state_with_default_dicts().call()

    class TestCopy:
        async def test_should_return_new_state_with_same_attributes(self, state):
            await state.test__copy__should_return_new_state_with_same_attributes().call()
