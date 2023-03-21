from collections import Counter

import pytest
import pytest_asyncio
from eth_keys import keys

from tests.utils.constants import TRANSACTIONS
from tests.utils.helpers import get_multicall_from_evm_txs


@pytest_asyncio.fixture(scope="module")
async def mock_kakarot(starknet, eth, account_proxy):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/accounts/eoa/mock_kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[eth.contract_address, account_proxy.class_hash],
    )


@pytest_asyncio.fixture(scope="module")
async def mock_externally_owned_account(starknet, mock_kakarot):
    private_key = keys.PrivateKey(int.to_bytes(0xDEAD, 32, "big"))
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/accounts/eoa/mock_externally_owned_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[
            mock_kakarot.contract_address,
            int(private_key.public_key.to_address(), 16),
        ],
    )


@pytest.mark.asyncio
class TestLibrary:
    async def test_execute_should_make_all_calls_and_return_concat_results(
        self, mock_externally_owned_account, eth
    ):
        private_key = keys.PrivateKey(int.to_bytes(0xDEAD, 32, "big"))
        (calls, calldata, expected_result) = get_multicall_from_evm_txs(
            evm_txs=TRANSACTIONS,
            private_key=private_key,
        )
        total_transferred_value = sum([x["value"] for x in TRANSACTIONS])

        # Mint tokens to the EOA
        await eth.mint(
            mock_externally_owned_account.contract_address, (total_transferred_value, 0)
        ).execute()

        assert (
            await mock_externally_owned_account.execute(calls, list(calldata)).call()
        ).result.response == expected_result

    async def test_should_transfer_value_to_destination_address(
        self, mock_kakarot, mock_externally_owned_account, eth
    ):
        private_key = keys.PrivateKey(int.to_bytes(0xDEAD, 32, "big"))

        txs = [t for t in TRANSACTIONS if t["to"]]
        (calls, calldata, _) = get_multicall_from_evm_txs(txs, private_key)
        total_transferred_value = sum([x["value"] for x in txs])

        evm_to_starknet_address = dict()
        expected_balances = Counter()

        # Storing initial balance, as eth storage persists across tests.
        initial_balance = (
            await eth.balanceOf(mock_externally_owned_account.contract_address).call()
        ).result.balance.low

        # Mint tokens to the EOA
        await eth.mint(
            mock_externally_owned_account.contract_address, (total_transferred_value, 0)
        ).execute()

        for transaction in txs:
            # Update expected balances
            evm_address = int(transaction["to"], 16)
            expected_balances[evm_address] += transaction["value"]

            # Update address mapping
            if evm_address not in evm_to_starknet_address:
                starknet_address = (
                    await mock_kakarot.compute_starknet_address(evm_address).call()
                ).result.contract_address
                evm_to_starknet_address[evm_address] = starknet_address

        # execute the multicall
        await mock_externally_owned_account.execute(calls, list(calldata)).execute()

        # verify the value was transferred
        for evm_address, amount in expected_balances.items():
            assert (
                await eth.balanceOf(evm_to_starknet_address[evm_address]).call()
            ).result.balance.low == amount

        # verify EOA has used all its recently minted balance
        assert (
            await eth.balanceOf(mock_externally_owned_account.contract_address).call()
        ).result.balance.low == initial_balance
