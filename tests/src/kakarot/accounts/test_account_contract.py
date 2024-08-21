import random
from textwrap import wrap
from unittest.mock import call, patch

import pytest
import rlp
from eth_account.account import Account
from eth_utils import keccak
from hypothesis import given, settings
from hypothesis.strategies import binary, composite, integers, lists, permutations
from starkware.cairo.lang.cairo_constants import DEFAULT_PRIME
from starkware.starknet.public.abi import (
    get_selector_from_name,
    get_storage_var_address,
)

from kakarot_scripts.constants import ARACHNID_PROXY_DEPLOYER, ARACHNID_PROXY_SIGNED_TX
from tests.utils.constants import CHAIN_ID, TRANSACTIONS
from tests.utils.errors import cairo_error
from tests.utils.helpers import generate_random_private_key, rlp_encode_signed_data
from tests.utils.hints import patch_hint
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256

CHAIN_ID_OFFSET = 35
V_OFFSET = 27


class TestAccountContract:
    @pytest.fixture(
        params=[
            0,
            10,
            100,
            pytest.param(1_000, marks=pytest.mark.slow),
            pytest.param(10_000, marks=pytest.mark.slow),
            pytest.param(100_000, marks=pytest.mark.slow),
        ]
    )
    def bytecode(self, request):
        return random.randbytes(request.param)

    class TestInitialize:
        @SyscallHandler.patch("IKakarot.register_account", lambda addr, data: [])
        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        @SyscallHandler.patch("Ownable_owner", 0x1234)
        def test_should_set_storage_variables(self, cairo_run):
            cairo_run("test__initialize", evm_address=0xABDE1)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_evm_address"), value=0xABDE1
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_is_initialized"), value=1
            )
            SyscallHandler.mock_call.assert_any_call(
                contract_address=0xDEAD,
                function_selector=get_selector_from_name("approve"),
                calldata=[0x1234, *int_to_uint256(2**256 - 1)],
            )
            SyscallHandler.mock_call.assert_any_call(
                contract_address=0x1234,
                function_selector=get_selector_from_name("register_account"),
                calldata=[0xABDE1],
            )

        @SyscallHandler.patch("IKakarot.register_account", lambda addr, data: [])
        @SyscallHandler.patch("Account_is_initialized", 1)
        def test_should_run_only_once(self, cairo_run):
            with cairo_error(message="Account already initialized"):
                cairo_run("test__initialize", evm_address=0xABDE1)

    class TestGetEvmAddress:
        @SyscallHandler.patch("Account_evm_address", 0xABDE1)
        def test_should_return_stored_address(self, cairo_run):
            output = cairo_run("test__get_evm_address__should_return_stored_address")
            assert output == 0xABDE1

    class TestWriteBytecode:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__write_bytecode", bytecode=[])

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_write_bytecode(self, cairo_run, bytecode):
            cairo_run("test__write_bytecode", bytecode=list(bytecode))
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_bytecode_len"),
                value=len(bytecode),
            )
            calls = [
                call(address=i, value=int(value, 16))
                for i, value in enumerate(wrap(bytecode.hex(), 2 * 31))
            ]
            SyscallHandler.mock_storage.assert_has_calls(calls)

    class TestBytecode:

        def storage(self, bytecode):
            chunks = wrap(bytecode.hex(), 2 * 31)

            def _storage(address):
                return (
                    int(chunks[address], 16)
                    if address != get_storage_var_address("Account_bytecode_len")
                    else len(bytecode)
                )

            return _storage

        def test_should_read_bytecode(self, cairo_run, bytecode):
            with patch.object(
                SyscallHandler, "mock_storage", side_effect=self.storage(bytecode)
            ) as mock_storage:
                output_len, output = cairo_run("test__bytecode")
            chunk_counts, remainder = divmod(len(bytecode), 31)
            addresses = list(range(chunk_counts + (remainder > 0)))
            calls = [call(address=address) for address in addresses]
            mock_storage.assert_has_calls(calls)
            assert output[:output_len] == list(bytecode)

        @given(bytecode=binary(min_size=1, max_size=400))
        @settings(max_examples=5)
        def test_should_raise_when_read_bytecode_zellic_issue_1279(
            self, cairo_program, cairo_run, bytecode
        ):
            with (
                patch_hint(
                    cairo_program,
                    "memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base\nassert res < ids.bound, f'split_int(): Limb {res} is out of range.'",
                    "memory[ids.output] = res = (int(ids.value) % PRIME + 1) % ids.base\nassert res < ids.bound, f'split_int(): Limb {res} is out of range.'",
                ),
                patch.object(
                    SyscallHandler, "mock_storage", side_effect=self.storage(bytecode)
                ),
            ):
                with cairo_error(message="Value is not empty"):
                    output_len, output = cairo_run("test__bytecode")

    class TestNonce:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_nonce", new_nonce=0x00)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_nonce(self, cairo_run):
            cairo_run("test__set_nonce", new_nonce=1)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_nonce"),
                value=1,
            )

    class TestJumpdests:
        class TestWriteJumpdests:
            @SyscallHandler.patch("Ownable_owner", 0xDEAD)
            def test_should_assert_only_owner(self, cairo_run):
                with cairo_error(message="Ownable: caller is not the owner"):
                    cairo_run("test__write_jumpdests", jumpdests=[])

            @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
            def test__should_store_valid_jumpdests(self, cairo_run):
                jumpdests = [0x02, 0x10, 0xFF]
                cairo_run("test__write_jumpdests", jumpdests=jumpdests)

                base_address = get_storage_var_address("Account_valid_jumpdests")
                calls = [
                    call(address=base_address + jumpdest, value=1)
                    for jumpdest in jumpdests
                ]

                SyscallHandler.mock_storage.assert_has_calls(calls)

        class TestReadJumpdests:
            @pytest.fixture
            def store_jumpdests(self, jumpdests):
                base_address = get_storage_var_address("Account_valid_jumpdests")
                valid_addresses = [base_address + jumpdest for jumpdest in jumpdests]

                def _storage(address):
                    return 1 if address in valid_addresses else 0

                return _storage

            @pytest.mark.parametrize("jumpdests", [[0x02, 0x10, 0xFF]])
            def test__should_return_if_jumpdest_valid(
                self, cairo_run, jumpdests, store_jumpdests
            ):
                with patch.object(
                    SyscallHandler, "mock_storage", side_effect=store_jumpdests
                ):
                    for jumpdest in jumpdests:
                        assert cairo_run("test__is_valid_jumpdest", index=jumpdest) == 1

                    base_address = get_storage_var_address("Account_valid_jumpdests")
                    calls = [
                        call(address=base_address + jumpdest) for jumpdest in jumpdests
                    ]
                    SyscallHandler.mock_storage.assert_has_calls(calls)

    class TestCodeHash:
        @given(code_hash=integers(min_value=0, max_value=2**256 - 1))
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run, code_hash):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_code_hash", code_hash=int_to_uint256(code_hash))

        @given(code_hash=integers(min_value=0, max_value=2**256 - 1))
        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test__should_set_code_hash(self, cairo_run, code_hash):
            with patch.object(SyscallHandler, "mock_storage") as mock_storage:
                low, high = int_to_uint256(code_hash)
                cairo_run("test__set_code_hash", code_hash=(low, high))
                code_hash_address = get_storage_var_address("Account_code_hash")
                ownable_address = get_storage_var_address("Ownable_owner")
                calls = [
                    call(address=ownable_address),
                    call(address=code_hash_address, value=low),
                    call(address=code_hash_address + 1, value=high),
                ]
                mock_storage.assert_has_calls(calls)

    class TestSetAuthorizedPreEIP155Transactions:
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_authorized_pre_eip155_tx", msg_hash=[0, 0])

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_authorized_pre_eip155_tx(self, cairo_run):
            msg_hash = int.from_bytes(keccak(b"test"), "big")
            cairo_run(
                "test__set_authorized_pre_eip155_tx",
                msg_hash=int_to_uint256(msg_hash),
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address(
                    "Account_authorized_message_hashes", *int_to_uint256(msg_hash)
                ),
                value=1,
            )

    class TestExecuteStarknetCall:
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run(
                    "test__execute_starknet_call",
                    called_address=0xABC,
                    function_selector=0xBCD,
                    calldata=[],
                )

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_fail_if_calling_kakarot(self, cairo_run):
            function_selector = 0xBCD
            with SyscallHandler.patch(function_selector, lambda addr, data: []):
                return_data, success = cairo_run(
                    "test__execute_starknet_call",
                    called_address=SyscallHandler.caller_address,
                    function_selector=function_selector,
                    calldata=[],
                )
                assert success == 0

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_execute_starknet_call(self, cairo_run):
            called_address = 0xABCDEF1234567890
            function_selector = 0x0987654321FEDCBA
            calldata = [random.randint(0, 255) for _ in range(32)]
            expected_return_data = [random.randint(0, 255) for _ in range(32)] + [
                int(True)
            ]
            with SyscallHandler.patch(
                function_selector, lambda addr, data: expected_return_data
            ):
                return_data, success = cairo_run(
                    "test__execute_starknet_call",
                    called_address=called_address,
                    function_selector=function_selector,
                    calldata=calldata,
                )

            assert return_data == expected_return_data
            assert success == 1
            SyscallHandler.mock_call.assert_any_call(
                contract_address=called_address,
                function_selector=function_selector,
                calldata=calldata,
            )

    class TestExecuteFromOutside:
        def test_should_raise_with_incorrect_signature_length(self, cairo_run):
            with cairo_error(message="Incorrect signature length"):
                cairo_run(
                    "test__execute_from_outside",
                    tx_data=[],
                    signature=list(range(4)),
                    chain_id=CHAIN_ID,
                )

        def test_should_raise_with_wrong_signature(self, cairo_run):
            with cairo_error(message="Invalid signature."):
                cairo_run(
                    "test__execute_from_outside",
                    tx_data=[1],
                    signature=list(range(5)),
                    chain_id=CHAIN_ID,
                )

        @composite
        def draw_signature_not_in_range(draw):
            # create signature with 4 elements < 2 ** 128 and one > 2 ** 128
            signature = draw(
                lists(
                    integers(min_value=0, max_value=2**128 - 1), min_size=4, max_size=4
                )
            )
            signature.append(
                draw(integers(min_value=2**128, max_value=DEFAULT_PRIME - 1))
            )
            # Draw randomly signature elements
            return draw(permutations(signature))

        @given(draw_signature_not_in_range())
        def test_should_raise_with_signature_values_not_in_range(
            self, cairo_run, draw_signature_not_in_range
        ):
            with cairo_error(message="Signatures values not in range"):
                cairo_run(
                    "test__execute_from_outside",
                    tx_data=[1],
                    signature=draw_signature_not_in_range,
                    chain_id=CHAIN_ID,
                )

        @SyscallHandler.patch("Account_evm_address", int(ARACHNID_PROXY_DEPLOYER, 16))
        def test_should_raise_unauthorized_pre_eip155_tx(self, cairo_run):
            rlp_decoded = rlp.decode(ARACHNID_PROXY_SIGNED_TX)
            v, r, s = rlp_decoded[-3:]
            signature = [
                *int_to_uint256(int.from_bytes(r, "big")),
                *int_to_uint256(int.from_bytes(s, "big")),
                int.from_bytes(v, "big"),
            ]
            unsigned_tx_data = rlp_decoded[:-3]
            tx_data = list(rlp.encode(unsigned_tx_data))

            with cairo_error(message="Unauthorized pre-eip155 transaction"):
                cairo_run(
                    "test__execute_from_outside",
                    tx_data=tx_data,
                    signature=signature,
                    chain_id=CHAIN_ID,
                )

        def test_should_raise_invalid_signature_for_invalid_chain_id_when_tx_type0_not_pre_eip155(
            self, cairo_run
        ):
            transaction = {
                "to": "0xF0109fC8DF283027b6285cc889F5aA624EaC1F55",
                "value": 1_000_000_000,
                "gas": 2_000_000,
                "gasPrice": 234567897654321,
                "nonce": 0,
                "chainId": CHAIN_ID,
                "data": b"",
            }
            tx_data = list(rlp_encode_signed_data(transaction))
            private_key = generate_random_private_key()
            address = int(private_key.public_key.to_checksum_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)
            signature = [*int_to_uint256(signed.r), *int_to_uint256(signed.s), signed.v]

            with (
                SyscallHandler.patch("Account_evm_address", address),
                cairo_error(message="Invalid signature."),
            ):
                cairo_run(
                    "test__execute_from_outside",
                    tx_data=tx_data,
                    signature=signature,
                    chain_id=CHAIN_ID + 1,
                )

        @SyscallHandler.patch("IKakarot.get_native_token", lambda _, __: [0xDEAD])
        @SyscallHandler.patch("IERC20.balanceOf", lambda _, __: int_to_uint256(10**128))
        @SyscallHandler.patch(
            "IKakarot.eth_send_raw_transaction",
            lambda _, __: [1, 0x68656C6C6F, 1, 1],  # hello
        )
        def test_pass_authorized_pre_eip155_transaction(self, cairo_run):
            rlp_decoded = rlp.decode(ARACHNID_PROXY_SIGNED_TX)
            v, r, s = rlp_decoded[-3:]
            signature = [
                *int_to_uint256(int.from_bytes(r, "big")),
                *int_to_uint256(int.from_bytes(s, "big")),
                int.from_bytes(v, "big"),
            ]
            unsigned_tx_data = rlp_decoded[:-3]
            encoded_unsigned_tx = rlp.encode(unsigned_tx_data)
            tx_data = list(encoded_unsigned_tx)
            tx_hash_low, tx_hash_high = int_to_uint256(
                int.from_bytes(keccak(encoded_unsigned_tx), "big")
            )

            with (
                SyscallHandler.patch(
                    "Account_evm_address", int(ARACHNID_PROXY_DEPLOYER, 16)
                ),
                SyscallHandler.patch(
                    "Account_authorized_message_hashes", tx_hash_low, tx_hash_high, 0x1
                ),
                SyscallHandler.patch("Account_nonce", 0),
            ):
                output_len, output = cairo_run(
                    "test__execute_from_outside",
                    tx_data=tx_data,
                    signature=signature,
                    chain_id=CHAIN_ID,
                )

            SyscallHandler.mock_event.assert_any_call(
                keys=[get_selector_from_name("transaction_executed")],
                data=[1, 0x68656C6C6F, 1, 1],
            )

            assert output_len == 1
            assert output[0] == 0x68656C6C6F

        @SyscallHandler.patch("IERC20.balanceOf", lambda _, __: int_to_uint256(10**128))
        @SyscallHandler.patch(
            "IKakarot.eth_send_raw_transaction",
            lambda _, __: [1, 0x68656C6C6F, 1, 1],  # hello
        )
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        def test_pass_all_transactions_types(self, cairo_run, seed, transaction):
            """
            Note: the seeds 41 and 42 have been manually selected after observing that some private keys
            were making the Counter deploy transaction failing because their signature parameters length (s and v)
            were not 32 bytes.
            """
            private_key = generate_random_private_key()
            address = int(private_key.public_key.to_checksum_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)
            signature = [*int_to_uint256(signed.r), *int_to_uint256(signed.s), signed.v]
            tx_data = list(rlp_encode_signed_data(transaction))

            with (
                SyscallHandler.patch("Account_evm_address", address),
                SyscallHandler.patch("Account_nonce", transaction.get("nonce", 0)),
            ):
                output_len, output = cairo_run(
                    "test__execute_from_outside",
                    tx_data=tx_data,
                    signature=signature,
                    chain_id=transaction.get("chainId") or CHAIN_ID,
                )

            SyscallHandler.mock_event.assert_any_call(
                keys=[get_selector_from_name("transaction_executed")],
                data=[1, 0x68656C6C6F, 1, 1],
            )

            assert output_len == 1
            assert output[0] == 0x68656C6C6F

        @SyscallHandler.patch("IERC20.balanceOf", lambda _, __: int_to_uint256(10**128))
        @SyscallHandler.patch(
            "IKakarot.eth_send_raw_transaction",
            lambda _, __: [1, 0x68656C6C6F, 1, 1],  # hello
        )
        def test_should_pass_all_data_len(self, cairo_run, bytecode):
            transaction = {
                "to": "0xF0109fC8DF283027b6285cc889F5aA624EaC1F55",
                "value": 0,
                "gas": 2_000_000,
                "gasPrice": 234567897654321,
                "nonce": 0,
                "chainId": CHAIN_ID,
                "data": bytecode,
            }
            tx_data = list(rlp_encode_signed_data(transaction))

            private_key = generate_random_private_key()
            address = int(private_key.public_key.to_checksum_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)
            signature = [*int_to_uint256(signed.r), *int_to_uint256(signed.s), signed.v]

            with (
                SyscallHandler.patch("Account_evm_address", address),
                SyscallHandler.patch("Account_nonce", transaction.get("nonce", 0)),
            ):
                output_len, output = cairo_run(
                    "test__execute_from_outside",
                    tx_data=tx_data,
                    signature=signature,
                    chain_id=transaction.get("chainId") or CHAIN_ID,
                )

            SyscallHandler.mock_event.assert_any_call(
                keys=[get_selector_from_name("transaction_executed")],
                data=[1, 0x68656C6C6F, 1, 1],
            )

            assert output_len == 1
            assert output[0] == 0x68656C6C6F
