import pytest

from tests.utils.constants import BLOCK_GAS_LIMIT, CHAIN_ID, Opcodes
from tests.utils.syscall_handler import SyscallHandler


class TestBlockInformation:
    @pytest.mark.parametrize(
        "opcode,expected_result",
        [
            (
                Opcodes.COINBASE,
                [0xACDFFE0CF08E20ED8BA10EA97A487004, 0x388CA486B82E20CC81965D056B4CDCA],
            ),
            (Opcodes.TIMESTAMP, [SyscallHandler.block_timestamp, 0]),
            (Opcodes.NUMBER, [SyscallHandler.block_number, 0]),
            (Opcodes.PREVRANDAO, [0, 0]),
            (Opcodes.GASLIMIT, [BLOCK_GAS_LIMIT, 0]),
            (Opcodes.CHAINID, [CHAIN_ID, 0]),
            (Opcodes.BASEFEE, [0, 0]),
        ],
    )
    def test__exec_block_information(self, cairo_run, opcode, expected_result):
        output = cairo_run("test__exec_block_information", opcode=opcode)
        assert output == expected_result
