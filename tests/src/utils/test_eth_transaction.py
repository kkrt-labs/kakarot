import random

import pytest
import pytest_asyncio
from eth_account.account import Account
from starkware.starknet.testing.starknet import Starknet

from tests.utils.constants import TRANSACTIONS
from tests.utils.errors import kakarot_error
from tests.utils.helpers import generate_random_evm_address, generate_random_private_key


@pytest_asyncio.fixture(scope="module")
async def eth_transaction(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/utils/test_eth_transaction.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestEthTransaction:
    class TestValidate:
        @pytest.mark.parametrize("seed", (41, 42))
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_pass_all_transactions_types(
            self, eth_transaction, seed, transaction
        ):
            """
            Note: the seeds 41 and 42 have been manually selected after observing that some private keys
            were making the Counter deploy transaction failing because their signature parameters length (s and v)
            were not 32 bytes
            """
            random.seed(seed)
            private_key = generate_random_private_key()
            address = private_key.public_key.to_checksum_address()
            signed = Account.sign_transaction(transaction, private_key)
            await eth_transaction.test__validate(
                int(address, 16), transaction["nonce"], list(signed["rawTransaction"])
            ).call()

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_chain_id(
            self, eth_transaction, transaction
        ):
            private_key = generate_random_private_key()
            address = private_key.public_key.to_checksum_address()
            t = {**transaction, "chainId": 1}
            signed = Account.sign_transaction(t, private_key)
            with kakarot_error():
                await eth_transaction.test__validate(
                    int(address, 16), transaction["nonce"], list(signed["rawTransaction"])
                ).call()

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_address(
            self, eth_transaction, transaction
        ):
            private_key = generate_random_private_key()
            address = int(generate_random_evm_address(), 16)
            signed = Account.sign_transaction(transaction, private_key)

            assert address != int(private_key.public_key.to_address(), 16)
            with kakarot_error():
                await eth_transaction.test__validate(
                    address, transaction["nonce"], list(signed["rawTransaction"])
                ).call()
