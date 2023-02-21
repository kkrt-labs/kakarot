import pytest
import pytest_asyncio
from eth_account import Account

from tests.utils.constants import TRANSACTIONS
from tests.utils.helpers import generate_random_private_key


@pytest_asyncio.fixture(scope="module")
async def mock_kakarot(starknet, eth):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/accounts/eoa/mock_kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[eth.contract_address],
    )


@pytest_asyncio.fixture(scope="module")
async def externally_owned_account(starknet, mock_kakarot):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/accounts/eoa/test_library.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[mock_kakarot.contract_address],
    )


@pytest.mark.asyncio
class TestLibrary:
    async def test_execute_should_make_all_calls_and_return_concat_results(
        self, externally_owned_account, eth
    ):
        private_key = generate_random_private_key()
        calls = []
        calldata = b""
        expected_result = []

        # Mint tokens to the EOA
        total_value = sum([x["value"] for x in TRANSACTIONS])
        ledger = dict()
        await eth.mint(
            externally_owned_account.contract_address, (total_value, 0)
        ).execute(caller_address=2)

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
                # Update ledger
                account_address = int(transaction["to"], 16)
                ledger[account_address] = (
                    int(ledger.get(account_address) or 0) + transaction["value"]
                )
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
            await externally_owned_account.test__execute__should_make_all_calls_and_return_concat_results(
                calls, list(calldata)
            ).execute()
        ).result.response == expected_result

        # verify the value was transfered
        for transaction in TRANSACTIONS:
            if transaction["to"] != "":
                account_address = int(transaction["to"], 16)
                assert (
                    await eth.balanceOf(account_address).call()
                ).result.balance.low == ledger[account_address]
        # verify EOA is empty
        assert (
            await eth.balanceOf(externally_owned_account.contract_address).call()
        ).result.balance.low == 0
