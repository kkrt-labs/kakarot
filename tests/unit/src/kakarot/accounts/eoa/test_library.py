import pytest
import pytest_asyncio
from eth_account import Account

from tests.utils.constants import TRANSACTIONS
from tests.utils.helpers import generate_random_private_key


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
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/accounts/eoa/mock_externally_owned_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[mock_kakarot.contract_address],
    )


@pytest.mark.asyncio
class TestLibrary:
    async def test_execute_should_make_all_calls_and_return_concat_results(
        self, mock_externally_owned_account
    ):
        private_key = generate_random_private_key()
        calls = []
        calldata = b""
        expected_result = []
        for transaction in TRANSACTIONS:
            tx = Account.sign_transaction(transaction, private_key)["rawTransaction"]
            calls += [
                (
                    0x0,  # to
                    0x0,  # selector
                    len(calldata),  # data_offset
                    len(tx),  # data_len
                )
            ]
            calldata += tx
            # Execute contract bytecode
            if transaction["to"] != "":
                expected_result += [
                    int(transaction["to"], 16),
                    transaction["value"],
                    transaction["gas"],
                    len(
                        bytes.fromhex(transaction.get("data", "").replace("0x", ""))
                    ),  # calldata_len
                    *list(
                        bytes.fromhex(transaction.get("data", "").replace("0x", ""))
                    ),  # calldata
                ]
            # Deploy Contract
            else:
                expected_result += [
                    len(
                        bytes.fromhex(transaction.get("data", "").replace("0x", ""))
                    ),  # calldata_len
                    *list(
                        bytes.fromhex(transaction.get("data", "").replace("0x", ""))
                    ),  # calldata
                ]

        assert (
            await mock_externally_owned_account.execute(calls, list(calldata)).call()
        ).result.response == expected_result

    async def test_should_transfer_value_to_destination_account(
        self, mock_kakarot, mock_externally_owned_account, eth
    ):
        private_key = generate_random_private_key()
        calls = []
        calldata = b""

        txs = [t for t in TRANSACTIONS if t["to"] != ""]
        total_transferred_value = sum([x["value"] for x in txs])

        evm_to_starknet_address = dict()
        expected_balances = dict()

        # Mint tokens to the EOA
        await eth.mint(
            mock_externally_owned_account.contract_address, (total_transferred_value, 0)
        ).execute()

        for transaction in txs:
            tx = Account.sign_transaction(transaction, private_key)["rawTransaction"]
            calls += [
                (
                    0x0,  # to
                    0x0,  # selector
                    len(calldata),  # data_offset
                    len(tx),  # data_len
                )
            ]
            calldata += tx

            # Update expected balances
            to_evm_address = int(transaction["to"], 16)
            expected_balances[to_evm_address] = (
                int(expected_balances.get(to_evm_address, 0)) + transaction["value"]
            )

            # Update address mapping
            if to_evm_address not in evm_to_starknet_address:
                to_starknet_address = (
                    await mock_kakarot.compute_starknet_address(to_evm_address).call()
                ).result.contract_address
                evm_to_starknet_address[to_evm_address] = to_starknet_address

        # execute the multicall
        await mock_externally_owned_account.execute(calls, list(calldata)).execute()

        # verify the value was transfered
        for to_evm_address, amount in expected_balances.items():
            assert (
                await eth.balanceOf(evm_to_starknet_address[to_evm_address]).call()
            ).result.balance.low == amount
        # verify EOA is empty
        assert (
            await eth.balanceOf(mock_externally_owned_account.contract_address).call()
        ).result.balance.low == 0
