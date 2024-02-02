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
            output = cairo_run(
                "test__decode",
                data=list(encoded_unsigned_tx),
            )

            expected_access_list = flatten_tx_access_list(
                transaction.get("accessList", [])
            )
            # count of addresses and each storage key in access list
            expected_access_list_len = sum(
                2 * len(x["storageKeys"]) + 2 for x in transaction.get("accessList", [])
            )
            expected_gas_price = (
                transaction.get("gasPrice") or transaction["maxFeePerGas"]
            )
            expected_to = (
                int(transaction["to"], 16)
                if isinstance(transaction["to"], str)
                else transaction["to"]
            )
            expected_data = (
                bytes.fromhex(transaction["data"][2:])
                if isinstance(transaction["data"], str)
                else transaction["data"]
            )

            value = output[6] + output[7] * 2**128
            data_len = output[9]
            data = bytes(output[10 : 10 + data_len])
            access_list_len = output[10 + data_len]
            access_list = output[
                11 + data_len : 11 + data_len + len(expected_access_list)
            ]

            assert transaction["nonce"] == output[2]
            assert expected_gas_price == output[3]
            assert transaction["gas"] == output[4]
            assert expected_to == output[5]
            assert transaction["value"] == value
            assert transaction["chainId"] == output[8]
            assert expected_data == data
            assert expected_access_list_len == access_list_len
            assert access_list == expected_access_list

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
