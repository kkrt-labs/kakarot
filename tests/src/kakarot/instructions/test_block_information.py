import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.constants import Opcodes
from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="module")
async def block_information(
    starknet: Starknet, blockhashes: dict, blockhash_registry: StarknetContract
):
    block_number = max(blockhashes["last_256_blocks"].keys())
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_block_information.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            *int_to_uint256(int(block_number)),
            blockhashes["last_256_blocks"][block_number],
            blockhash_registry.contract_address,
        ],
    )


@pytest.mark.asyncio
class TestBlockInformation:
    async def test__blockhash__should_return_hash_when_in_range(
        self, block_information, blockhashes
    ):
        block_number = max(blockhashes["last_256_blocks"].keys())
        result = await block_information.test__exec_block_information(
            Opcodes.BLOCKHASH,
            [int_to_uint256(int(block_number))],
        ).call()
        assert result.result.result == int_to_uint256(
            blockhashes["last_256_blocks"][block_number]
        )

    async def test__blockhash__should_return_0_when_out_of_range(
        self, block_information, blockhashes
    ):
        block_number = max(blockhashes["last_256_blocks"].keys())
        result = await block_information.test__exec_block_information(
            Opcodes.BLOCKHASH,
            [int_to_uint256(int(block_number) - 260)],
        ).call()
        assert result.result.result == (0, 0)

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
            (Opcodes.GASLIMIT, (1_000_000, 0)),
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
