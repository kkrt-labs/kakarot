from collections import OrderedDict
from unittest.mock import patch

import pytest

from tests.utils.constants import BIG_CHAIN_ID, BLOCK_GAS_LIMIT, CHAIN_ID, Opcodes
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
            (Opcodes.BLOBHASH, 0),
            (Opcodes.BLOBBASEFEE, 0),
        ],
    )
    @SyscallHandler.patch(
        "Kakarot_coinbase", 0xCA40796AFB5472ABAED28907D5ED6FC74C04954A
    )
    @SyscallHandler.patch("Kakarot_block_gas_limit", BLOCK_GAS_LIMIT)
    @patch.object(SyscallHandler, "block_timestamp", 0x1234)
    def test__exec_block_information(self, cairo_run, opcode, expected_result):
        output = cairo_run("test__exec_block_information", opcode=opcode)
        assert output == hex(expected_result)

    @patch.object(
        SyscallHandler,
        "tx_info",
        OrderedDict(
            {
                "version": 1,
                "account_contract_address": 0xABDE1,
                "max_fee": int(1e17),
                "signature_len": None,
                "signature": [],
                "transaction_hash": 0xABDE1,
                "chain_id": BIG_CHAIN_ID,
                "nonce": 1,
            }
        ),
    )
    def test__exec_chain_id__should_return_mod_64(self, cairo_run):
        output = cairo_run("test__exec_block_information", opcode=Opcodes.CHAINID)
        assert output == hex(BIG_CHAIN_ID % 2**64)
