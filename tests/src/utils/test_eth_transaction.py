import random

import pytest
from eth_account._utils.transaction_utils import transaction_rpc_to_rlp_structure
from eth_account.account import Account
from rlp import encode

from tests.utils.constants import TRANSACTIONS
from tests.utils.errors import cairo_error
from tests.utils.helpers import (
    generate_random_evm_address,
    generate_random_private_key,
    rlp_encode_signed_data,
    serialize_accesslist,
)
from tests.utils.uint256 import int_to_uint256


class TestEthTransaction:
    class TestValidate:
        @pytest.mark.parametrize("seed", (41, 42))
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_pass_all_transactions_types(
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

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            cairo_run(
                "test__validate",
                address=int(address, 16),
                nonce=transaction["nonce"],
                r=int_to_uint256(signed.r),
                s=int_to_uint256(signed.s),
                v=signed["v"],
                tx_data=list(encoded_unsigned_tx),
            )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_chain_id(self, cairo_run, transaction):
            private_key = generate_random_private_key()
            address = private_key.public_key.to_checksum_address()
            transaction = {**transaction, "chainId": 1}
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            with cairo_error():
                cairo_run(
                    "test__validate",
                    address=int(address, 16),
                    nonce=transaction["nonce"],
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
                    r=int_to_uint256(signed.r),
                    s=int_to_uint256(signed.s),
                    v=signed["v"],
                    tx_data=list(encoded_unsigned_tx),
                )

    class TestAccessList:
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        def test_should_parse_access_list(self, cairo_run, transaction):
            rlp_structure_tx = transaction_rpc_to_rlp_structure(transaction)
            access_list = rlp_structure_tx["accessList"]
            sanitized_access_list = [
                (
                    bytes.fromhex(address[2:]),
                    tuple(
                        bytes.fromhex(storage_key[2:]) for storage_key in storage_keys
                    ),
                )
                for address, storage_keys in access_list
            ]
            encoded_access_list = encode(sanitized_access_list)

            output = cairo_run(
                "test__parse_access_list", data=list(encoded_access_list)
            )
            expected_output = serialize_accesslist(transaction["accessList"])
            assert output == expected_output
