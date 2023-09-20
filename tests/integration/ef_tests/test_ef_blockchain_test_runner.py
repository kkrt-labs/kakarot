import pytest
from runner import assert_post_state, do_transaction, write_test_state
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract


@pytest.mark.usefixtures("starknet_snapshot")
class TestEFBlockhain:
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
        owner,
        ef_test,
    ):
        """
        Run a single test case based on the Ethereum Foundation Blockchain test format data.

        See https://ethereum-tests.readthedocs.io/en/latest/blockchain-ref.html
        """
        await write_test_state(
            account_proxy_class,
            contract_account_class,
            externally_owned_account_class,
            get_contract_account,
            get_starknet_address,
            eth,
            kakarot,
            starknet,
            ef_test["pre"],
        )
        await do_transaction(
            ef_test["blocks"], get_starknet_address, kakarot, owner, starknet
        )
        await assert_post_state(
            get_contract_account,
            get_starknet_address,
            eth,
            kakarot,
            starknet,
            ef_test["postState"],
        )
