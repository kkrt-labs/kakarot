import pytest
from eth_account.account import Account

from tests.utils.constants import CHAIN_ID
from tests.utils.errors import kakarot_error

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


@pytest.mark.asyncio
class TestExternallyOwnedAccount:
    class TestGetEvmAddress:
        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_return_the_evm_address_used_at_deploy(
            self, addresses, address_idx
        ):
            address = addresses[address_idx]
            call_info = await address.starknet_contract.get_evm_address().call()
            assert call_info.result.evm_address == int(address.address, 16)

    class TestValidate:
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_pass_all_transactions_types(self, owner, transaction):
            # to and selector are starknet params and are not used
            to = 0x0
            selector = 0x0
            data_offset = 0
            signed = Account.sign_transaction(transaction, owner.private_key)
            data_len = len(signed["rawTransaction"])
            await owner.starknet_contract.__validate__(
                [(to, selector, data_offset, data_len)], list(signed["rawTransaction"])
            ).call()

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_chain_id(self, owner, transaction):
            # to and selector are starknet params and are not used
            to = 0x0
            selector = 0x0
            data_offset = 0
            t = {**transaction, "chainId": 1}
            signed = Account.sign_transaction(t, owner.private_key)
            data_len = len(signed["rawTransaction"])
            with kakarot_error():
                await owner.starknet_contract.__validate__(
                    [(to, selector, data_offset, data_len)],
                    list(signed["rawTransaction"]),
                ).call()

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_altered_signature(self, owner, transaction):
            # to and selector are starknet params and are not used
            to = 0x0
            selector = 0x0
            data_offset = 0
            signed = Account.sign_transaction(transaction, owner.private_key)
            data_len = len(signed["rawTransaction"])
            with kakarot_error():
                await owner.starknet_contract.__validate__(
                    [(to, selector, data_offset, data_len)],
                    list(signed["rawTransaction"]),
                ).call()

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_raise_with_wrong_address(self, owner, other, transaction):
            # to and selector are starknet params and are not used
            to = 0x0
            selector = 0x0
            data_offset = 0
            signed = Account.sign_transaction(transaction, other.private_key)
            data_len = len(signed["rawTransaction"])
            with kakarot_error():
                await owner.starknet_contract.__validate__(
                    [(to, selector, data_offset, data_len)],
                    list(signed["rawTransaction"]),
                ).call()

    class TestValidateDeclare:
        async def test_should_raise(self, owner):
            with kakarot_error():
                await owner.starknet_contract.__validate_declare__(0).call()

    @pytest.mark.parametrize("interface_id, res", [(0, False), (10, True)])
    async def test_supports_interface(self, interface_id, res):
        pass

    async def test_bytecode(self, owner):
        assert (await owner.starknet_contract.bytecode()).result.bytecode == []

    async def test_bytecode_len(self, owner):
        assert (await owner.starknet_contract.bytecode_len()).result.len == 0

    class TestExecute:
        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        async def test_should_pass_all_transactions_types(self, owner, transaction):
            # to and selector are starknet params and are not used
            to = 0x0
            selector = 0x0
            data_offset = 0
            signed = Account.sign_transaction(transaction, owner.private_key)
            data_len = len(signed["rawTransaction"])
            await owner.starknet_contract.__execute__(
                [(to, selector, data_offset, data_len)], list(signed["rawTransaction"])
            ).call()
