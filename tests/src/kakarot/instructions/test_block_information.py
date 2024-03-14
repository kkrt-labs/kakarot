from unittest.mock import patch

import pytest

from tests.utils.constants import BLOCK_GAS_LIMIT, CHAIN_ID, Opcodes
from tests.utils.syscall_handler import SyscallHandler


class TestBlockInformation:
    @pytest.mark.parametrize(
        "opcode,expected_result",
        [
            (
                Opcodes.COINBASE,
                0xCA40796AFB5472ABAED28907D5ED6FC74C04954A,
            ),
            (Opcodes.TIMESTAMP, 0x1234),
            (Opcodes.NUMBER, SyscallHandler.block_number),
            (Opcodes.PREVRANDAO, 0),
            (Opcodes.GASLIMIT, BLOCK_GAS_LIMIT),
            (Opcodes.CHAINID, CHAIN_ID),
            (Opcodes.BASEFEE, 0),
            (Opcodes.BLOBBASEFEE, 0),
        ],
    )
    @SyscallHandler.patch("coinbase", 0xCA40796AFB5472ABAED28907D5ED6FC74C04954A)
    @SyscallHandler.patch("block_gas_limit", BLOCK_GAS_LIMIT)
    @patch.object(SyscallHandler, "block_timestamp", 0x1234)
    def test__exec_block_information(self, cairo_run, opcode, expected_result):
        output = cairo_run("test__exec_block_information", opcode=opcode)
        assert output == hex(expected_result)
