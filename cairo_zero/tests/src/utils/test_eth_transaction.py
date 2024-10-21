import pytest
from eth_account._utils.transaction_utils import transaction_rpc_to_rlp_structure
from eth_account._utils.validation import LEGACY_TRANSACTION_VALID_VALUES
from eth_account.typed_transactions.access_list_transaction import AccessListTransaction
from eth_account.typed_transactions.dynamic_fee_transaction import DynamicFeeTransaction
from hypothesis import given
from hypothesis import strategies as st
from rlp import encode

from tests.utils.constants import INVALID_TRANSACTIONS, TRANSACTIONS
from tests.utils.errors import cairo_error
from tests.utils.helpers import flatten_tx_access_list, rlp_encode_signed_data


class TestEthTransaction:

    class TestDecodeTransaction:

        async def test_should_raise_with_list_items(self, cairo_run):
            transaction = {
                "nonce": 0,
                "gasPrice": 234567897654321,
                "gas": 2_000_000,
                "to": "0xF0109fC8DF283027b6285cc889F5aA624EaC1F55",
                "value": ["000000000"],
                "data": b"",
            }
            with cairo_error():
                cairo_run("test__decode", data=list(encode(list(transaction.values()))))

        @given(value=st.integers(min_value=2**248))
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        @pytest.mark.parametrize(
            "key",
            [
                "nonce",
                "gasPrice",
                "gas",
                "value",
                "chainId",
                "maxFeePerGas",
                "maxPriorityFeePerGas",
            ],
        )
        async def test_should_raise_with_params_overflow(
            self, cairo_run, transaction, key, value
        ):
            # Not all transactions have all keys
            if key not in transaction:
                return

            # Value can be up to 32 bytes
            if key == "value":
                value *= 256

            # Override the value
            transaction = {**transaction, key: value}

            tx_type = transaction.pop("type", 0)
            # Remove accessList from the transaction if it exists, not relevant for this test
            if tx_type > 0:
                transaction["accessList"] = []

            # Encode the transaction
            encoded_unsigned_tx = (
                b"" if tx_type == 0 else tx_type.to_bytes(1, "big")
            ) + encode(
                [
                    transaction[key]
                    for key in [
                        LEGACY_TRANSACTION_VALID_VALUES.keys(),
                        dict(AccessListTransaction.unsigned_transaction_fields).keys(),
                        dict(DynamicFeeTransaction.unsigned_transaction_fields).keys(),
                    ][tx_type]
                ]
            )

            # Run the test
            with cairo_error():
                cairo_run("test__decode", data=list(encoded_unsigned_tx))

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_decode_all_transactions_types(
            self, cairo_run, transaction
        ):
            encoded_unsigned_tx = rlp_encode_signed_data(transaction)
            decoded_tx = cairo_run("test__decode", data=list(encoded_unsigned_tx))

            expected_data = (
                "0x" + transaction["data"].hex()
                if isinstance(transaction["data"], bytes)
                else transaction["data"]
            )
            expected_access_list = flatten_tx_access_list(
                transaction.get("accessList", [])
            )
            expected_to = transaction["to"] or None

            assert transaction["nonce"] == decoded_tx["signer_nonce"]
            assert (
                transaction.get("gasPrice", transaction.get("maxFeePerGas"))
                == decoded_tx["max_fee_per_gas"]
            )
            assert transaction["gas"] == decoded_tx["gas_limit"]
            assert expected_to == decoded_tx["destination"]
            assert transaction["value"] == int(decoded_tx["amount"], 16)
            # pre-eip155 txs have an internal chain_id set to 0 in the decoded tx
            assert transaction.get("chainId") == decoded_tx["chain_id"]
            assert expected_data == decoded_tx["payload"]
            assert expected_access_list == decoded_tx["access_list"]

        @pytest.mark.parametrize("transaction", INVALID_TRANSACTIONS)
        async def test_should_panic_on_unsupported_tx_types(
            self, cairo_run, transaction
        ):
            encoded_unsigned_tx = rlp_encode_signed_data(transaction)
            with cairo_error("Kakarot: transaction type not supported"):
                cairo_run(
                    "test__decode",
                    data=list(encoded_unsigned_tx),
                )

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

        def test_should_raise_when_data_len_is_zero(self, cairo_run):
            with cairo_error("tx_data_len is zero"):
                cairo_run("test__get_tx_type", data_len=0, data=[1, 2, 3])
