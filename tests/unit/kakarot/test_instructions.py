import re

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def instructions(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/kakarot/test_instructions.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
class TestInstructions:
    async def test__unknown_opcode(self, instructions):
        with pytest.raises(Exception) as e:
            await instructions.test__unknown_opcode().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: UnknownOpcode"

    async def test__not_implemented_opcode(self, instructions):
        with pytest.raises(Exception) as e:
            await instructions.test__not_implemented_opcode().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == "Kakarot: NotImplementedOpcode"
