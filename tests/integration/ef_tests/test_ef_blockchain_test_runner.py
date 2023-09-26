import pytest
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract

from tests.integration.ef_tests.runner import assert_post_state, setup_test_state
from tests.utils.helpers import hex_string_to_bytes_array


@pytest.mark.usefixtures("starknet_snapshot")
@pytest.mark.EFTests
class TestEFBlockchain:
    async def test_case(
        self,
        account_proxy_class: DeclaredClass,
        contract_account_class: DeclaredClass,
        externally_owned_account_class: DeclaredClass,
        get_contract_account,
        get_starknet_address,
        eth: StarknetContract,
        kakarot: StarknetContract,
        starknet: StarknetContract,
        ef_blockchain_test,
    ):
        """
        Run a single test case based on the Ethereum Foundation Blockchain test format data.

        See https://ethereum-tests.readthedocs.io/en/latest/blockchain-ref.html
        """
        await setup_test_state(
            account_proxy_class,
            contract_account_class,
            externally_owned_account_class,
            get_contract_account,
            get_starknet_address,
            eth,
            kakarot,
            starknet,
            ef_blockchain_test["pre"],
        )

        # See: https://ethereum-tests.readthedocs.io/en/latest/test_filler/blockchain_filler.html#blocks for details.
        for block in ef_blockchain_test["blocks"]:
            for transaction in block["transactions"]:
                starknet_address = get_starknet_address(int(transaction["sender"], 16))

                await kakarot.eth_send_transaction(
                    to=int(transaction["to"], 16),
                    gas_limit=int(transaction["gasLimit"], 16),
                    gas_price=int(transaction["gasPrice"], 16),
                    value=int(transaction["value"], 16),
                    data=hex_string_to_bytes_array(transaction["data"]),
                ).execute(caller_address=starknet_address)

            # do we really have to do this manually? (yes)
            await starknet.state.state.increment_nonce(starknet_address)

        await assert_post_state(
            get_contract_account,
            get_starknet_address,
            starknet,
            ef_blockchain_test["postState"],
        )
