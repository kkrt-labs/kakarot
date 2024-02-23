import json

import pytest
from starkware.starknet.public.abi import get_storage_var_address

from scripts.ef_tests.fetch import EF_TESTS_PARSED_DIR
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256


def parse_state(state):
    return {
        int(address, 16): {
            "balance": int(account["balance"], 16),
            "code": list(bytes.fromhex(account["code"].replace("0x", ""))),
            "nonce": int(account["nonce"], 16),
            "storage": {
                get_storage_var_address("storage_", *int_to_uint256(int(key, 16))): int(
                    value, 16
                )
                for key, value in account["storage"].items()
            },
        }
        for address, account in state.items()
    }


@pytest.mark.EFTests
class TestEFBlockchain:

    async def test_case(
        self,
        cairo_run,
        ef_blockchain_test,
    ):
        test_case = json.loads((EF_TESTS_PARSED_DIR / ef_blockchain_test).read_text())
        block = test_case["blocks"][0]
        with SyscallHandler.patch_state(parse_state(test_case["pre"])):
            tx = block["transactions"][0]
            evm, state, gas_used = cairo_run("test_should_return_correct_state", **tx)

        parsed_state = {
            int(address, 16): {
                "balance": int(account["balance"], 16),
                "code": account["code"],
                "nonce": account["nonce"],
                "storage": {
                    key: int(value, 16)
                    for key, value in account["storage"].items()
                    if int(value, 16) > 0
                },
            }
            for address, account in state["accounts"].items()
            if int(address, 16) > 10
        }
        assert parsed_state == parse_state(test_case["postState"])
        assert gas_used == int(block["blockHeader"]["gasUsed"], 16)
