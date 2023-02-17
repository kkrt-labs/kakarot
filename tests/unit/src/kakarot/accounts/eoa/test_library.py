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
async def externally_owned_account(starknet, mock_kakarot, eth):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/accounts/eoa/test_library.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[mock_kakarot.contract_address, eth.contract_address],
    )


@pytest.mark.asyncio
class TestLibrary:
    async def test_execute_should_make_all_calls_and_return_concat_results(
        self, externally_owned_account
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
            await externally_owned_account.test__execute__should_make_all_calls_and_return_concat_results(
                calls, list(calldata)
            ).call()
        ).result.response == expected_result

    async def test_approval_is_infinite(
        self, externally_owned_account, mock_kakarot, eth
    ):
        # Ensure approval is max after deployment
        assert (
            str(
                (
                    await eth.allowance(
                        externally_owned_account.contract_address,
                        mock_kakarot.contract_address,
                    ).call()
                ).result.remaining
            )
            == "Uint256(low=340282366920938463463374607431768211455, high=340282366920938463463374607431768211455)"
        )

        # Perform a token transfer
        mock_kakarot.transfer_from_contract(
            externally_owned_account.contract_address,
            mock_kakarot.contract_address,
            (1000, 0),
        )

        # After a token transfer by kakarot, the allowance should still be max
        assert (
            str(
                (
                    await eth.allowance(
                        externally_owned_account.contract_address,
                        mock_kakarot.contract_address,
                    ).call()
                ).result.remaining
            )
            == "Uint256(low=340282366920938463463374607431768211455, high=340282366920938463463374607431768211455)"
        )
