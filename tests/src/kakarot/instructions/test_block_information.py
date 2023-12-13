import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.constants import Opcodes


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
            (Opcodes.TIMESTAMP, ("{timestamp}", 0)),
            (Opcodes.NUMBER, ("{block_number}", 0)),
            (Opcodes.PREVRANDAO, (0, 0)),
            (Opcodes.GASLIMIT, (20_000_000, 0)),
            (Opcodes.CHAINID, (int.from_bytes(b"KKRT", "big"), 0)),
            (Opcodes.BASEFEE, (0, 0)),
        ],
    )
    async def test__exec_block_information(
        self, block_information, opcode, expected_result
    ):
        result, timestamp, block_number = (
            await block_information.test__exec_block_information(opcode, []).call()
        ).result
        expected_result = tuple(
            v
            if isinstance(v, int)
            else int(v.format(timestamp=timestamp, block_number=block_number))
            for v in expected_result
        )
        assert result == expected_result
