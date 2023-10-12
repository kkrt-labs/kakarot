import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def evm(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_evm.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestInstructions:
    async def test__unknown_opcode(self, evm):
        result = await evm.test__unknown_opcode().call()
        assert result.result.revert_reason == list(b"Kakarot: UnknownOpcode")
