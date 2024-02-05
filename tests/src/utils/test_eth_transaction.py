import random

import pytest
from eth_account._utils.transaction_utils import transaction_rpc_to_rlp_structure
from eth_account.account import Account
from rlp import encode

from tests.utils.constants import TRANSACTIONS
from tests.utils.errors import cairo_error
from tests.utils.helpers import (
    flatten_tx_access_list,
    generate_random_evm_address,
    generate_random_private_key,
    rlp_encode_signed_data,
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
                chain_id=transaction["chainId"],
                r=int_to_uint256(signed.r),
                s=int_to_uint256(signed.s),
                v=signed["v"],
                tx_data=list(encoded_unsigned_tx),
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

    class TestDecodeTransaction:
        @pytest.mark.parametrize(
            "transaction",
            [
                *TRANSACTIONS[:-2],
                pytest.param(
                    TRANSACTIONS[-2],
                    marks=pytest.mark.xfail(
                        reason="TODO: https://github.com/kkrt-labs/kakarot/issues/899"
                    ),
                ),
                pytest.param(
                    TRANSACTIONS[-1],
                    marks=pytest.mark.xfail(
                        reason="TODO: https://github.com/kkrt-labs/kakarot/issues/899"
                    ),
                ),
            ],
        )
        async def test_should_decode_all_transactions_types(
            self, cairo_run, transaction
        ):
            encoded_unsigned_tx = rlp_encode_signed_data(transaction)
            decoded_tx = cairo_run(
                "test__decode",
                data=list(encoded_unsigned_tx),
            )

            expected_data = (
                "0x" + transaction["data"].hex()
                if isinstance(transaction["data"], bytes)
                else transaction["data"]
            )
            expected_access_list = flatten_tx_access_list(
                transaction.get("accessList", [])
            )

            assert transaction["nonce"] == decoded_tx["signer_nonce"]
            assert (
                transaction.get("gasPrice", transaction.get("maxFeePerGas"))
                == decoded_tx["max_fee_per_gas"]
            )
            assert transaction["gas"] == decoded_tx["gas_limit"]
            assert transaction["to"] == decoded_tx["destination"]
            assert transaction["value"] == int(decoded_tx["amount"], 16)
            assert transaction["chainId"] == decoded_tx["chain_id"]
            assert expected_data == decoded_tx["payload"]
            assert expected_access_list == decoded_tx["access_list"]

    class TestParseAccessList:
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        def test_should_parse_access_list(self, cairo_run, transaction):
            rlp_structure_tx = transaction_rpc_to_rlp_structure(transaction)
            sanitized_access_list = [
                (
                    bytes.fromhex(address[2:]),
                    tuple(
                        bytes.fromhex(storage_key[2:]) for storage_key in storage_keys
                    ),
                )
                for address, storage_keys in rlp_structure_tx.get("accessList", [])
            ]
            encoded_access_list = encode(sanitized_access_list)

            output = cairo_run(
                "test__parse_access_list", data=list(encoded_access_list)
            )
            expected_output = flatten_tx_access_list(transaction.get("accessList", []))
            assert output == expected_output

    class TestGetTxType:
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        def test_should_return_tx_type(self, cairo_run, transaction):
            encoded_unsigned_tx = rlp_encode_signed_data(transaction)
            tx_type = cairo_run("test__get_tx_type", data=list(encoded_unsigned_tx))
            assert tx_type == transaction.get("type", 0)
