import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error


@pytest_asyncio.fixture(scope="module")
async def instructions(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/test_instructions.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
class TestInstructions:
    async def test__unknown_opcode(self, instructions):
        with kakarot_error("Kakarot: UnknownOpcode"):
            await instructions.test__unknown_opcode().call()

    async def test__not_implemented_opcode(self, instructions):
        with kakarot_error("Kakarot: NotImplementedOpcode"):
            await instructions.test__not_implemented_opcode().call()
