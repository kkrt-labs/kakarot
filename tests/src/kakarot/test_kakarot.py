import json
from types import MethodType
from unittest.mock import PropertyMock, patch

import pytest
from eth_abi import decode, encode
from eth_utils import keccak
from eth_utils.address import to_checksum_address
from starkware.starknet.public.abi import get_storage_var_address
from web3._utils.abi import map_abi_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS
from web3.exceptions import NoABIFunctionsFound

from kakarot_scripts.ef_tests.fetch import EF_TESTS_PARSED_DIR
from tests.utils.constants import TRANSACTION_GAS_LIMIT
from tests.utils.errors import cairo_error
from tests.utils.helpers import felt_to_signed_int
from tests.utils.syscall_handler import SyscallHandler, parse_state

CONTRACT_ADDRESS = 1234
OWNER = to_checksum_address(f"0x{0xABDE1:040x}")
OTHER = to_checksum_address(f"0x{0xE1A5:040x}")

EVM_ADDRESS = 0x42069


@pytest.fixture(scope="module")
def get_contract(cairo_run):
    from kakarot_scripts.utils.kakarot import get_contract as get_solidity_contract

    def _factory(contract_app, contract_name):
        def _wrap_cairo_run(fun):
            def _wrapper(self, *args, **kwargs):
                origin = kwargs.pop("origin", 0)
                gas_limit = kwargs.pop("gas_limit", int(TRANSACTION_GAS_LIMIT))
                gas_price = kwargs.pop("gas_price", 0)
                value = kwargs.pop("value", 0)
                data = self.get_function_by_name(fun)(
                    *args, **kwargs
                )._encode_transaction_data()
                evm, state, gas, _ = cairo_run(
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

                types = [o["type"] for o in abi["outputs"]]
                decoded = decode(types, bytes(evm["return_data"]))
                normalized = map_abi_data(BASE_RETURN_NORMALIZERS, types, decoded)
                return normalized[0] if len(normalized) == 1 else normalized

            return _wrapper

        contract = get_solidity_contract(contract_app, contract_name)
        try:
            for fun in contract.functions:
                setattr(contract, fun, MethodType(_wrap_cairo_run(fun), contract))
        except NoABIFunctionsFound:
            pass

        return contract

    return _factory


class TestKakarot:

    class TestNativeToken:
        @pytest.mark.slow
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_native_token", address=0xABC)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_native_token(self, cairo_run):
            token_address = 0xABCDE12345
            cairo_run("test__set_native_token", address=token_address)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Kakarot_native_token_address"),
                value=token_address,
            )

    class TestTransferOwnership:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__transfer_ownership", new_owner=0xABC)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_transfer_ownership(self, cairo_run):
            new_owner = 0xABCDE12345
            cairo_run("test__transfer_ownership", new_owner=new_owner)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Ownable_owner"), value=new_owner
            )

    class TestBaseFee:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_base_fee", base_fee=0xABC)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_base_fee(self, cairo_run):
            base_fee = 0x100
            cairo_run("test__set_base_fee", base_fee=base_fee)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Kakarot_base_fee"), value=base_fee
            )

    class TestCoinbase:
        @pytest.mark.slow
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_coinbase", coinbase=0xABC)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_coinbase(self, cairo_run):
            coinbase = 0xC0DE
            cairo_run("test__set_coinbase", coinbase=coinbase)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Kakarot_coinbase"), value=coinbase
            )

    class TestPrevRandao:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_prev_randao", prev_randao=0xABC)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_prev_randao(self, cairo_run):
            prev_randao = 0x123
            cairo_run("test__set_prev_randao", prev_randao=prev_randao)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Kakarot_prev_randao"),
                value=prev_randao,
            )

    class TestBlockGasLimit:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_block_gas_limit", block_gas_limit=0xABC)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_block_gas_limit(self, cairo_run):
            block_gas_limit = 0x1000
            cairo_run("test__set_block_gas_limit", block_gas_limit=block_gas_limit)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Kakarot_block_gas_limit"),
                value=block_gas_limit,
            )

    class TestAccountContractClassHash:
        @pytest.mark.slow
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_account_contract_class_hash", class_hash=0xABC)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_account_contract_class_hash(self, cairo_run):
            class_hash = 0x123
            cairo_run("test__set_account_contract_class_hash", class_hash=class_hash)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Kakarot_account_contract_class_hash"),
                value=class_hash,
            )

    class TestUninitializedAccountClassHash:
        @pytest.mark.slow
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run(
                    "test__set_uninitialized_account_class_hash", class_hash=0xABC
                )

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_uninitialized_account_class_hash(self, cairo_run):
            class_hash = 0x123
            cairo_run(
                "test__set_uninitialized_account_class_hash", class_hash=class_hash
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address(
                    "Kakarot_uninitialized_account_class_hash"
                ),
                value=class_hash,
            )

    class TestAuthorizedCairoPrecompileCaller:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run(
                    "test__set_authorized_cairo_precompile_caller",
                    caller_address=0xABC,
                    authorized=0xBCD,
                )

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_authorized_cairo_precompile_caller(self, cairo_run):
            caller = 0x123
            authorized = 0x456
            cairo_run(
                "test__set_authorized_cairo_precompile_caller",
                caller_address=caller,
                authorized=authorized,
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address(
                    "Kakarot_authorized_cairo_precompiles_callers",
                    caller,
                ),
                value=authorized,
            )

    class Cairo1HelpersClass:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_cairo1_helpers_class_hash", class_hash=0xABC)

    class TestRegisterAccount:
        @SyscallHandler.patch("Kakarot_evm_to_starknet_address", EVM_ADDRESS, 0)
        @patch(
            "tests.utils.syscall_handler.SyscallHandler.caller_address",
            new_callable=PropertyMock,
        )
        def test_register_account_should_store_evm_to_starknet_address_mapping(
            self, mock_caller_address, cairo_run
        ):
            starknet_address = cairo_run(
                "compute_starknet_address", evm_address=EVM_ADDRESS
            )
            mock_caller_address.return_value = starknet_address

            cairo_run("test__register_account", evm_address=EVM_ADDRESS)

            SyscallHandler.mock_storage.assert_called_with(
                address=get_storage_var_address(
                    "Kakarot_evm_to_starknet_address", EVM_ADDRESS
                ),
                value=starknet_address,
            )

        @pytest.mark.slow
        @SyscallHandler.patch("Kakarot_evm_to_starknet_address", 0x42069, 1)
        @patch(
            "tests.utils.syscall_handler.SyscallHandler.caller_address",
            new_callable=PropertyMock,
        )
        def test_register_account_should_fail_existing_entry(
            self, mock_caller_address, cairo_run
        ):
            starknet_address = cairo_run(
                "compute_starknet_address", evm_address=EVM_ADDRESS
            )
            mock_caller_address.return_value = starknet_address

            with cairo_error(message="Kakarot: account already registered"):
                cairo_run("test__register_account", evm_address=EVM_ADDRESS)

        @SyscallHandler.patch("Kakarot_evm_to_starknet_address", EVM_ADDRESS, 0)
        @patch(
            "tests.utils.syscall_handler.SyscallHandler.caller_address",
            new_callable=PropertyMock,
        )
        def test_register_account_should_fail_caller_not_resolved_address(
            self, mock_caller_address, cairo_run
        ):
            expected_starknet_address = cairo_run(
                "compute_starknet_address", evm_address=EVM_ADDRESS
            )
            mock_caller_address.return_value = expected_starknet_address // 2

            with cairo_error(
                message=f"Kakarot: Caller should be {felt_to_signed_int(expected_starknet_address)}, got {expected_starknet_address // 2}"
            ):
                cairo_run("test__register_account", evm_address=EVM_ADDRESS)

    class TestEthCall:
        @pytest.mark.slow
        @pytest.mark.SolmateERC20
        @SyscallHandler.patch(
            "IAccount.is_valid_jumpdest",
            lambda addr, data: [1],
        )
        @SyscallHandler.patch(
            "IAccount.get_code_hash", lambda sn_addr, data: [0x1, 0x1]
        )
        async def test_erc20_transfer(self, get_contract):
            erc20 = await get_contract("Solmate", "ERC20")
            amount = int(1e18)
            initial_state = {
                CONTRACT_ADDRESS: {
                    "code": list(erc20.bytecode_runtime),
                    "storage": {
                        "0x2": amount,
                        keccak(encode(["address", "uint8"], [OWNER, 3])).hex(): amount,
                    },
                    "balance": 0,
                    "nonce": 0,
                }
            }
            with SyscallHandler.patch_state(parse_state(initial_state)):
                evm, *_ = erc20.transfer(OTHER, amount, origin=int(OWNER, 16))
            assert not evm["reverted"]

        @pytest.mark.slow
        @pytest.mark.SolmateERC721
        @SyscallHandler.patch(
            "IAccount.is_valid_jumpdest",
            lambda addr, data: [1],
        )
        @SyscallHandler.patch(
            "IAccount.get_code_hash", lambda sn_addr, data: [0x1, 0x1]
        )
        async def test_erc721_transfer(self, get_contract):
            erc721 = await get_contract("Solmate", "ERC721")
            token_id = 1337
            initial_state = {
                CONTRACT_ADDRESS: {
                    "code": list(erc721.bytecode_runtime),
                    "storage": {
                        keccak(encode(["uint256", "uint8"], [token_id, 2])).hex(): int(
                            OWNER, 16
                        ),
                        keccak(encode(["address", "uint8"], [OWNER, 3])).hex(): 1,
                    },
                    "balance": 0,
                    "nonce": 0,
                }
            }
            with SyscallHandler.patch_state(parse_state(initial_state)):
                evm, *_ = erc721.transferFrom(
                    OWNER, OTHER, token_id, origin=int(OWNER, 16)
                )
            assert not evm["reverted"]

        @pytest.mark.slow
        @pytest.mark.NoCI
        @pytest.mark.EFTests
        @pytest.mark.parametrize(
            "ef_blockchain_test",
            EF_TESTS_PARSED_DIR.glob("*walletConstruction_d0g1v0_Cancun*.json"),
        )
        async def test_case(
            self,
            cairo_run,
            ef_blockchain_test,
        ):
            test_case = json.loads(ef_blockchain_test.read_text())
            block = test_case["blocks"][0]
            tx = block["transactions"][0]
            with SyscallHandler.patch_state(parse_state(test_case["pre"])):
                evm, state, gas_used, required_gas = cairo_run(
                    "eth_call",
                    origin=int(tx["sender"], 16),
                    to=int(tx.get("to"), 16) if tx.get("to") else None,
                    gas_limit=int(tx["gasLimit"], 16),
                    gas_price=int(tx["gasPrice"], 16),
                    value=int(tx["value"], 16),
                    data=tx["data"],
                    nonce=int(tx["nonce"], 16),
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

        @pytest.mark.skip
        async def test_failing_contract(self, cairo_run):
            initial_state = {
                CONTRACT_ADDRESS: {
                    "code": bytes.fromhex("ADDC0DE1"),
                    "storage": {},
                    "balance": 0,
                    "nonce": 0,
                }
            }
            with SyscallHandler.patch_state(parse_state(initial_state)):
                evm, *_ = cairo_run(
                    "eth_call",
                    origin=int(OWNER, 16),
                    to=CONTRACT_ADDRESS,
                    gas_limit=0,
                    gas_price=0,
                    value=0,
                    data="0xADD_DATA",
                )
            assert not evm["reverted"]

    class TestLoopProfiling:
        @pytest.mark.slow
        @pytest.mark.NoCI
        @pytest.mark.parametrize("steps", [10, 50, 100, 200])
        @SyscallHandler.patch("IAccount.is_valid_jumpdest", lambda addr, data: [1])
        async def test_loop_profiling(self, get_contract, steps):
            plain_opcodes = await get_contract("PlainOpcodes", "PlainOpcodes")
            initial_state = {
                CONTRACT_ADDRESS: {
                    "code": list(plain_opcodes.bytecode_runtime),
                    "storage": {},
                    "balance": 0,
                    "nonce": 0,
                }
            }
            with SyscallHandler.patch_state(parse_state(initial_state)):
                res = plain_opcodes.loopProfiling(steps)
            assert res == sum(x for x in range(steps))
