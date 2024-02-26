import json
from types import MethodType

import pytest
from eth_abi import encode
from eth_utils import keccak
from eth_utils.address import to_checksum_address
from web3 import Web3
from web3._utils.abi import map_abi_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS
from web3.exceptions import NoABIFunctionsFound

from scripts.ef_tests.fetch import EF_TESTS_PARSED_DIR
from scripts.utils.kakarot import get_contract
from tests.utils.syscall_handler import SyscallHandler, parse_state

TEST_AMOUNT = int(1e18)
CONTRACT_ADDRESS = 1234
OWNER = to_checksum_address(f"0x{0xABDE1:040x}")
OTHER = to_checksum_address(f"0x{0xE1A5:040x}")


@pytest.fixture(scope="module")
def initial_state():
    return {
        CONTRACT_ADDRESS: {
            "code": list(
                bytes.fromhex(
                    json.load(open("solidity_contracts/build/ERC20.sol/ERC20.json"))[
                        "deployedBytecode"
                    ]["object"][2:]
                )
            ),
            "storage": {
                "0x2": TEST_AMOUNT,
                keccak(encode(["address", "uint8"], [OWNER, 3])).hex(): TEST_AMOUNT,
            },
            "balance": 0,
            "nonce": 0,
        }
    }


@pytest.fixture(scope="module")
def erc_20(cairo_run, initial_state):
    def _wrap_cairo_run(fun):
        def _wrapper(self, *args, **kwargs):
            origin = kwargs.pop("origin", 0)
            gas_limit = kwargs.pop("gas_limit", int(1e9))
            gas_price = kwargs.pop("gas_price", 0)
            value = kwargs.pop("value", 0)
            data = self.get_function_by_name(fun)(
                *args, **kwargs
            )._encode_transaction_data()
            evm, state, gas = cairo_run(
                "eth_call",
                origin=origin,
                to=CONTRACT_ADDRESS,
                gas_limit=gas_limit,
                gas_price=gas_price,
                value=value,
                data=data,
            )
            abi = self.get_function_by_name(fun).abi
            if abi["stateMutability"] not in ["pure", "view"]:
                return evm, state, gas

            codec = Web3().codec
            types = [o["type"] for o in abi["outputs"]]
            decoded = codec.decode(types, bytes(evm["return_data"]))
            normalized = map_abi_data(BASE_RETURN_NORMALIZERS, types, decoded)
            return normalized[0] if len(normalized) == 1 else normalized

        return _wrapper

    contract = get_contract("Solmate", "ERC20")
    try:
        for fun in contract.functions:
            setattr(contract, fun, MethodType(_wrap_cairo_run(fun), contract))
    except NoABIFunctionsFound:
        pass

    return contract


@pytest.mark.SolmateERC20
class TestKakarot:
    class TestEthCall:
        @pytest.mark.SolmateERC20
        async def test_should_transfer(self, erc_20, initial_state):
            with SyscallHandler.patch_state(parse_state(initial_state)):
                evm, *_ = erc_20.transfer(OTHER, TEST_AMOUNT, origin=int(OWNER, 16))
            assert not evm["reverted"]

        @pytest.mark.EFTests
        # @pytest.mark.parametrize(
        #     "ef_blockchain_test", EF_TESTS_PARSED_DIR.glob("*.json")
        # )
        async def test_case(
            self,
            cairo_run,
            ef_blockchain_test,
        ):
            test_case = json.loads(
                (EF_TESTS_PARSED_DIR / ef_blockchain_test).read_text()
            )
            block = test_case["blocks"][0]
            with SyscallHandler.patch_state(parse_state(test_case["pre"])):
                tx = block["transactions"][0]
                evm, state, gas_used = cairo_run(
                    "eth_call",
                    origin=int(tx["sender"], 16),
                    to=int(tx.get("to"), 16) if tx.get("to") else None,
                    gas_limit=int(tx["gasLimit"], 16),
                    gas_price=int(tx["gasPrice"], 16),
                    value=int(tx["value"], 16),
                    data=tx["data"],
                )

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
