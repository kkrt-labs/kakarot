import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import cairo_error


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
        with cairo_error("Kakarot: UnknownOpcode"):
            await evm.test__unknown_opcode().call()

    async def test__not_implemented_opcode(self, evm):
        with cairo_error("Kakarot: NotImplementedOpcode"):
            await evm.test__not_implemented_opcode().call()
