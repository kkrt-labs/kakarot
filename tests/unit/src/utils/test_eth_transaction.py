import pytest
import pytest_asyncio
from eth_account.account import Account

from tests.utils.constants import CHAIN_ID
from tests.utils.errors import kakarot_error
from tests.utils.helpers import generate_random_private_key

# Taken from eth_account.account.Account.sign_transaction docstring
TRANSACTIONS = [
    {
        # Note that the address must be in checksum format or native bytes:
        "to": "0xF0109fC8DF283027b6285cc889F5aA624EaC1F55",
        "value": 1000000000,
        "gas": 2000000,
        "gasPrice": 234567897654321,
        "nonce": 0,
        "chainId": CHAIN_ID,
    },
    {
        "type": 1,
        "gas": 100000,
        "gasPrice": 1000000000,
        "data": "0x616263646566",
        "nonce": 34,
        "to": "0x09616C3d61b3331fc4109a9E41a8BDB7d9776609",
        "value": "0x5af3107a4000",
        "accessList": (
            {
                "address": "0x0000000000000000000000000000000000000001",
                "storageKeys": (
                    "0x0100000000000000000000000000000000000000000000000000000000000000",
                ),
            },
        ),
        "chainId": CHAIN_ID,
    },
    {
        "type": 2,
        "gas": 100000,
        "maxFeePerGas": 2000000000,
        "maxPriorityFeePerGas": 2000000000,
        "data": "0x616263646566",
        "nonce": 34,
        "to": "0x09616C3d61b3331fc4109a9E41a8BDB7d9776609",
        "value": "0x5af3107a4000",
        "accessList": (
            {
                "address": "0x0000000000000000000000000000000000000001",
                "storageKeys": (
                    "0x0100000000000000000000000000000000000000000000000000000000000000",
                ),
            },
        ),
        "chainId": CHAIN_ID,
    },
]


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
