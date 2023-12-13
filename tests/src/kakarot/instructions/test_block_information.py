import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.constants import (
    BLOCK_GAS_LIMIT,
    BLOCK_NUMBER,
    BLOCK_TIMESTAMP,
    CHAIN_ID,
    Opcodes,
)


@pytest_asyncio.fixture(scope="module")
async def block_information(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_block_information.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestBlockInformation:
    @pytest.mark.parametrize(
        "opcode,expected_result",
        [
            (
                Opcodes.COINBASE,
                (0xACDFFE0CF08E20ED8BA10EA97A487004, 0x388CA486B82E20CC81965D056B4CDCA),
            ),
            (Opcodes.TIMESTAMP, (BLOCK_TIMESTAMP, 0)),
            (Opcodes.NUMBER, (BLOCK_NUMBER, 0)),
            (Opcodes.PREVRANDAO, (0, 0)),
            (Opcodes.GASLIMIT, (BLOCK_GAS_LIMIT, 0)),
            (Opcodes.CHAINID, (CHAIN_ID, 0)),
            (Opcodes.BASEFEE, (0, 0)),
        ],
    )
    async def test__exec_block_information(
        self, block_information, opcode, expected_result
    ):
        (result,) = (
            await block_information.test__exec_block_information(opcode, []).call()
        ).result
        assert result == expected_result
