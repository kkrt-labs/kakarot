import pytest
import pytest_asyncio
from eth_account.account import Account

from tests.utils.constants import TRANSACTIONS
from tests.utils.errors import kakarot_error
from tests.utils.helpers import generate_random_private_key


@pytest_asyncio.fixture
async def eth_transaction(starknet):
    return await starknet.deploy(
        source="./tests/unit/src/utils/test_eth_transaction.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestEthTransaction:
    class TestValidate:
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_pass_all_transactions_types(
            self, eth_transaction, transaction
        ):
            private_key = generate_random_private_key()
            address = private_key.public_key.to_checksum_address()
            signed = Account.sign_transaction(transaction, private_key)
            await eth_transaction.test__validate(
                int(address, 16), list(signed["rawTransaction"])
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
                    int(address, 16), list(signed["rawTransaction"])
                ).call()

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_address(
            self, eth_transaction, transaction
        ):
            private_key = generate_random_private_key()
            address = generate_random_private_key().public_key.to_checksum_address()
            signed = Account.sign_transaction(transaction, private_key)
            with kakarot_error():
                await eth_transaction.test__validate(
                    int(address, 16), list(signed["rawTransaction"])
                ).call()
