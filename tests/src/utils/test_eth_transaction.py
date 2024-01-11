import random

import pytest
from eth_account.account import Account

from tests.utils.constants import TRANSACTIONS
from tests.utils.errors import cairo_error
from tests.utils.helpers import (
    generate_random_evm_address,
    generate_random_private_key,
    rlp_encode_signed_data,
)
from tests.utils.uint256 import int_to_uint256


@pytest.fixture(scope="module")
def program(cairo_compile):
    return cairo_compile("tests/src/utils/test_eth_transaction.cairo")


class TestEthTransaction:
    class TestValidate:
        @pytest.mark.parametrize("seed", (41, 42))
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_pass_all_transactions_types(
            self, cairo_run, program, seed, transaction
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
                program,
                "test__validate",
                {
                    "address": int(address, 16),
                    "nonce": transaction["nonce"],
                    "r": int_to_uint256(signed.r),
                    "s": int_to_uint256(signed.s),
                    "v": signed["v"],
                    "tx_data": list(encoded_unsigned_tx),
                },
            )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_chain_id(
            self, cairo_run, program, transaction
        ):
            private_key = generate_random_private_key()
            address = private_key.public_key.to_checksum_address()
            transaction = {**transaction, "chainId": 1}
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            with cairo_error():
                cairo_run(
                    program,
                    "test__validate",
                    {
                        "address": int(address, 16),
                        "nonce": transaction["nonce"],
                        "r": int_to_uint256(signed.r),
                        "s": int_to_uint256(signed.s),
                        "v": signed["v"],
                        "tx_data": list(encoded_unsigned_tx),
                    },
                )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_address(
            self, cairo_run, program, transaction
        ):
            private_key = generate_random_private_key()
            address = int(generate_random_evm_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            assert address != int(private_key.public_key.to_address(), 16)
            with cairo_error():
                cairo_run(
                    program,
                    "test__validate",
                    {
                        "address": int(address, 16),
                        "nonce": transaction["nonce"],
                        "r": int_to_uint256(signed.r),
                        "s": int_to_uint256(signed.s),
                        "v": signed["v"],
                        "tx_data": list(encoded_unsigned_tx),
                    },
                )

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_nonce(
            self, cairo_run, program, transaction
        ):
            private_key = generate_random_private_key()
            address = int(generate_random_evm_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            encoded_unsigned_tx = rlp_encode_signed_data(transaction)

            assert address != int(private_key.public_key.to_address(), 16)
            with cairo_error():
                cairo_run(
                    program,
                    "test__validate",
                    {
                        "address": int(address, 16),
                        "nonce": transaction["nonce"],
                        "r": int_to_uint256(signed.r),
                        "s": int_to_uint256(signed.s),
                        "v": signed["v"],
                        "tx_data": list(encoded_unsigned_tx),
                    },
                )
