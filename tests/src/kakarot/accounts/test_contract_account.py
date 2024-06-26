import random
from textwrap import wrap
from unittest.mock import call, patch

import pytest
import rlp
from eth_account._utils.legacy_transactions import (
    serializable_unsigned_transaction_from_dict,
)
from eth_account.account import Account
from eth_utils import keccak
from starkware.starknet.public.abi import (
    get_selector_from_name,
    get_storage_var_address,
)

from kakarot_scripts.constants import ARACHNID_PROXY_DEPLOYER, ARACHNID_PROXY_SIGNED_TX
from tests.utils.constants import CAIRO1_HELPERS_CLASS_HASH, CHAIN_ID, TRANSACTIONS
from tests.utils.errors import cairo_error
from tests.utils.helpers import (
    generate_random_evm_address,
    generate_random_private_key,
    rlp_encode_signed_data,
)
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256

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
            with cairo_error(message="Account already initialized"):
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
                output_len, output = cairo_run("test__bytecode")
            chunk_counts, remainder = divmod(len(bytecode), 31)
            addresses = list(range(chunk_counts + (remainder > 0)))
            calls = [call(address=address) for address in addresses]
            mock_storage.assert_has_calls(calls)
            assert output[:output_len] == list(bytecode)

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

    class TestImplementation:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run("test__set_implementation", new_implementation=0x00)

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        def test_should_set_implementation(self, cairo_run):
            cairo_run("test__set_implementation", new_implementation=0x1234)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("Account_implementation"), value=0x1234
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

            @pytest.fixture
            def patch_account_storage(self, account_code):
                code_len_address = get_storage_var_address("Account_bytecode_len")
                base_jumpdests_address = get_storage_var_address(
                    "Account_valid_jumpdests"
                )
                chunks = wrap(account_code, 2 * 31)

                def _storage(address, value=None):
                    if value is not None:
                        SyscallHandler.patches[address] = value
                        return
                    if address == code_len_address:
                        return len(bytes.fromhex(account_code))
                    elif address >= base_jumpdests_address:
                        return 0
                    return int(chunks[address], 16)

                return _storage

            # Code contains both valid and invalid jumpdests
            # PUSH1 4  // Offset 0
            # JUMP     // Offset 2 (previous instruction occupies 2 bytes)
            # INVALID  // Offset 3
            # JUMPDEST // Offset 4
            # PUSH1 1  // Offset 5
            # PUSH1 0x5B // invalid jumpdest
            @pytest.mark.parametrize(
                "account_code, jumpdests, results",
                [("600456fe5b6001605b", [0x04, 0x08], [1, 0])],
            )
            def test__should_return_if_jumpdest_valid_when_not_stored(
                self, cairo_run, account_code, jumpdests, results, patch_account_storage
            ):
                with patch.object(
                    SyscallHandler, "mock_storage", side_effect=patch_account_storage
                ):
                    for jumpdest, result in zip(jumpdests, results):
                        assert (
                            cairo_run("test__is_valid_jumpdest", index=jumpdest)
                            == result
                        )

                    base_address = get_storage_var_address("Account_valid_jumpdests")
                    jumpdests_initialized_address = get_storage_var_address(
                        "Account_jumpdests_initialized"
                    )
                    expected_read_calls = [
                        call(address=base_address + jumpdest) for jumpdest in jumpdests
                    ] + [call(address=jumpdests_initialized_address)]

                    expected_write_calls = [
                        call(address=base_address + jumpdest, value=1)
                        for jumpdest, result in zip(jumpdests, results)
                        if result == 1
                    ] + [call(address=jumpdests_initialized_address, value=1)]

                    SyscallHandler.mock_storage.assert_has_calls(expected_read_calls)
                    SyscallHandler.mock_storage.assert_has_calls(expected_write_calls)

    class SetAuthorizedPreEIP155Transactions:
        async def test_should_assert_only_owner(self, cairo_run):
            with cairo_error(message="Ownable: caller is not the owner"):
                cairo_run(
                    "test__set_authorized_pre_eip155_tx",
                    transaction_hash_low=0x00,
                    transaction_hash_high=0x00,
                )

        async def test_should_set_authorized_pre_eip155_tx(self, cairo_run):
            msg_hash = int.from_bytes(keccak(b"test"), "big")
            cairo_run(
                "test__set_authorized_pre_eip155_tx",
                transaction_hash=int_to_uint256(msg_hash),
            )
            tx_hash_low, tx_hash_high = int_to_uint256(msg_hash)
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address(
                    "Account_authorized_message_hashes", tx_hash_low, tx_hash_high
                ),
                value=1,
            )

    class TestValidate:
        @pytest.mark.parametrize("seed", (41, 42))
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        @SyscallHandler.patch(
            "Account_cairo1_helpers_class_hash", CAIRO1_HELPERS_CLASS_HASH
        )
        def test_should_pass_all_transactions_types(self, cairo_run, seed, transaction):
            """
            Note: the seeds 41 and 42 have been manually selected after observing that some private keys
            were making the Counter deploy transaction failing because their signature parameters length (s and v)
            were not 32 bytes.
            """
            random.seed(seed)
            private_key = generate_random_private_key()
            address = int(private_key.public_key.to_checksum_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            unsigned_transaction = serializable_unsigned_transaction_from_dict(
                transaction
            )
            unsigned_transaction.hash()

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)
            tx_data = list(encoded_unsigned_tx)

            cairo_run(
                "test__validate",
                address=address,
                nonce=transaction["nonce"],
                chain_id=transaction.get("chainId") or CHAIN_ID,
                r=int_to_uint256(signed.r),
                s=int_to_uint256(signed.s),
                v=signed["v"],
                tx_data=tx_data,
            )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_signed_chain_id(
            self, cairo_run, transaction
        ):
            private_key = generate_random_private_key()
            address = int(private_key.public_key.to_checksum_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            with cairo_error(message="Invalid chain id"):
                cairo_run(
                    "test__validate",
                    address=address,
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
            with cairo_error("Invalid signature."):
                cairo_run(
                    "test__validate",
                    address=address,
                    nonce=transaction["nonce"],
                    chain_id=transaction.get("chainId") or CHAIN_ID,
                    r=int_to_uint256(signed.r),
                    s=int_to_uint256(signed.s),
                    v=signed["v"],
                    tx_data=list(encoded_unsigned_tx),
                )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_nonce(self, cairo_run, transaction):
            private_key = generate_random_private_key()
            address = int(private_key.public_key.to_checksum_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            with cairo_error(message="Invalid nonce"):
                cairo_run(
                    "test__validate",
                    address=address,
                    nonce=transaction["nonce"] + 1,
                    chain_id=transaction.get("chainId") or CHAIN_ID,
                    r=int_to_uint256(signed.r),
                    s=int_to_uint256(signed.s),
                    v=signed["v"],
                    tx_data=list(encoded_unsigned_tx),
                )

        async def test_should_fail_unauthorized_pre_eip155_tx(self, cairo_run):
            rlp_decoded = rlp.decode(ARACHNID_PROXY_SIGNED_TX)
            v, r, s = rlp_decoded[-3:]
            unsigned_tx_data = rlp_decoded[:-3]
            unsigned_encoded_tx = rlp.encode(unsigned_tx_data)

            with cairo_error(message="Unauthorized pre-eip155 transaction"):
                cairo_run(
                    "test__validate",
                    address=int(ARACHNID_PROXY_DEPLOYER, 16),
                    nonce=0,
                    chain_id=CHAIN_ID,
                    r=int_to_uint256(int.from_bytes(r, "big")),
                    s=int_to_uint256(int.from_bytes(s, "big")),
                    v=int.from_bytes(v, "big"),
                    tx_data=list(unsigned_encoded_tx),
                )

        async def test_should_validate_authorized_pre_eip155_tx(self, cairo_run):
            rlp_decoded = rlp.decode(ARACHNID_PROXY_SIGNED_TX)
            v, r, s = rlp_decoded[-3:]
            unsigned_tx_data = rlp_decoded[:-3]
            unsigned_encoded_tx = rlp.encode(unsigned_tx_data)
            tx_hash_low, tx_hash_high = int_to_uint256(
                int.from_bytes(keccak(unsigned_encoded_tx), "big")
            )

            with SyscallHandler.patch(
                "Account_authorized_message_hashes",
                tx_hash_low,
                tx_hash_high,
                0x1,
            ):
                cairo_run(
                    "test__validate",
                    address=int(ARACHNID_PROXY_DEPLOYER, 16),
                    nonce=0,
                    chain_id=CHAIN_ID,
                    r=int_to_uint256(int.from_bytes(r, "big")),
                    s=int_to_uint256(int.from_bytes(s, "big")),
                    v=int.from_bytes(v, "big"),
                    tx_data=list(unsigned_encoded_tx),
                )

            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address(
                    "Account_authorized_message_hashes", tx_hash_low, tx_hash_high
                )
            )
