import random
from textwrap import wrap
from unittest.mock import call, patch

import pytest
from eth_account._utils.legacy_transactions import (
    serializable_unsigned_transaction_from_dict,
)
from eth_account.account import Account
from starkware.starknet.public.abi import (
    get_selector_from_name,
    get_storage_var_address,
)

from tests.utils.constants import CAIRO1_HELPERS_CLASS_HASH, CHAIN_ID, TRANSACTIONS
from tests.utils.errors import cairo_error
from tests.utils.helpers import (
    generate_random_evm_address,
    generate_random_private_key,
    rlp_encode_signed_data,
)
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256
from tests.utils.helpers import pack_into_u64_words

CHAIN_ID_OFFSET = 35
V_OFFSET = 27

class TestContractAccount:
    @pytest.fixture(params=[0, 10, 100, 1000, 10000])
    def bytecode(self, request):
        random.seed(0)
        return random.randbytes(request.param)

    class TestInitialize:
        @SyscallHandler.patch("IKakarot.register_account", lambda addr, data: [])
        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        @SyscallHandler.patch(
            "IKakarot.get_cairo1_helpers_class_hash",
            lambda addr, data: [CAIRO1_HELPERS_CLASS_HASH],
        )
        def test_should_set_storage_variables(self, cairo_run):
            cairo_run(
                "test__initialize",
                kakarot_address=0x1234,
                evm_address=0xABDE1,
                implementation_class=0xC1A55,
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_evm_address"), value=0xABDE1
            )

            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Ownable_owner"), value=0x1234
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_is_initialized"), value=1
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_implementation"), value=0xC1A55
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_cairo1_helpers_class_hash"),
                value=CAIRO1_HELPERS_CLASS_HASH,
            )
            SyscallHandler.mock_event.assert_any_call(
                keys=[get_selector_from_name("OwnershipTransferred")], data=[0, 0x1234]
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
            with cairo_error():
                cairo_run(
                    "test__initialize",
                    kakarot_address=0x1234,
                    evm_address=0xABDE1,
                    implementation_class=0xC1A55,
                )

    class TestGetEvmAddress:
        @SyscallHandler.patch("Account_evm_address", 0xABDE1)
        def test_should_return_stored_address(self, cairo_run):
            output = cairo_run("test__get_evm_address__should_return_stored_address")
            assert output == 0xABDE1

    class TestWriteBytecode:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error():
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
        @pytest.fixture
        def storage(self, bytecode):
            chunks = wrap(bytecode.hex(), 2 * 31)

            def _storage(address):
                return (
                    int(chunks[address], 16)
                    if address != get_storage_var_address("Account_bytecode_len")
                    else len(bytecode)
                )

            return _storage

        def test_should_read_bytecode(self, cairo_run, bytecode, storage):
            with patch.object(
                SyscallHandler, "mock_storage", side_effect=storage
            ) as mock_storage:
                output_len, output = cairo_run("test__read_bytecode")
            chunk_counts, remainder = divmod(len(bytecode), 31)
            addresses = list(range(chunk_counts + (remainder > 0)))
            calls = [call(address=address) for address in addresses]
            mock_storage.assert_has_calls(calls)
            assert output[:output_len] == list(bytecode)

    class TestValidate:
        @pytest.mark.parametrize("seed", (41, 42))
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        @SyscallHandler.patch("Account_cairo1_helpers_class_hash", CAIRO1_HELPERS_CLASS_HASH)
        def test_should_pass_all_transactions_types(
            self, cairo_run, seed, transaction
        ):
            """
            Note: the seeds 41 and 42 have been manually selected after observing that some private keys
            were making the Counter deploy transaction failing because their signature parameters length (s and v)
            were not 32 bytes.
            """
            random.seed(seed)
            private_key = generate_random_private_key()
            address = private_key.public_key.to_checksum_address()
            signed = Account.sign_transaction(transaction, private_key)

            unsigned_transaction = serializable_unsigned_transaction_from_dict(
                transaction
            )
            transaction_hash = unsigned_transaction.hash()

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)
            tx_data = list(encoded_unsigned_tx)

            cairo_run(
                "test__validate",
                address=int(address, 16),
                nonce=transaction["nonce"],
                chain_id=transaction["chainId"],
                r=int_to_uint256(signed.r),
                s=int_to_uint256(signed.s),
                v=signed["v"],
                tx_data=tx_data,
            )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_chain_id(self, cairo_run, transaction):
            private_key = generate_random_private_key()
            address = private_key.public_key.to_checksum_address()
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            with cairo_error():
                cairo_run(
                    "test__validate",
                    address=int(address, 16),
                    nonce=transaction["nonce"],
                    chain_id=transaction["chainId"] + 1,
                    r=int_to_uint256(signed.r),
                    s=int_to_uint256(signed.s),
                    v=signed["v"],
                    tx_data=list(encoded_unsigned_tx),
                )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_address(self, cairo_run, transaction):
            private_key = generate_random_private_key()
            address = int(generate_random_evm_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            assert address != int(private_key.public_key.to_address(), 16)
            with cairo_error():
                cairo_run(
                    "test__validate",
                    address=int(address, 16),
                    nonce=transaction["nonce"],
                    chain_id=transaction["chainId"],
                    r=int_to_uint256(signed.r),
                    s=int_to_uint256(signed.s),
                    v=signed["v"],
                    tx_data=list(encoded_unsigned_tx),
                )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_nonce(self, cairo_run, transaction):
            private_key = generate_random_private_key()
            address = int(generate_random_evm_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            assert address != int(private_key.public_key.to_address(), 16)
            with cairo_error():
                cairo_run(
                    "test__validate",
                    address=int(address, 16),
                    nonce=transaction["nonce"],
                    chain_id=transaction["chainId"],
                    r=int_to_uint256(signed.r),
                    s=int_to_uint256(signed.s),
                    v=signed["v"],
                    tx_data=list(encoded_unsigned_tx),
                )
