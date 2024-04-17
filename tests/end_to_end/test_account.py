import pytest
import pytest_asyncio
from starknet_py.net.full_node_client import FullNodeClient

TOTAL_SUPPLY = 10000 * 10**18
TEST_AMOUNT = 10 * 10**18


@pytest.fixture(scope="session")
async def class_hashes():
    """
    All declared class hashes.
    """
    from kakarot_scripts.utils.starknet import get_declarations

    return get_declarations()


@pytest_asyncio.fixture(scope="function")
async def counter(deploy_solidity_contract, new_account):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "Counter",
        caller_eoa=new_account.starknet_contract,
    )


@pytest.fixture(autouse=True)
async def cleanup(invoke, class_hashes):
    yield
    await invoke(
        "kakarot",
        "set_account_contract_class_hash",
        class_hashes["account_contract"],
    )
    await invoke(
        "kakarot", "set_cairo1_helpers_class_hash", class_hashes["Cairo1Helpers"]
    )


async def assert_counter_transaction_success(counter, new_account):
    """
    Assert that the transaction sent, other than upgrading the account contract, is successful.
    """
    assert await counter.count() == 0
    await counter.inc(caller_eoa=new_account.starknet_contract)
    assert await counter.count() == 1


@pytest.mark.asyncio(scope="session")
@pytest.mark.AccountContract
class TestAccount:
    class TestCounter:
        async def test_inc_counter(self, counter, new_account):
            await counter.inc(caller_eoa=new_account.starknet_contract)

    class TestAutoUpgradeOnTransaction:
        async def test_should_upgrade_outdated_account_on_transfer(
            self,
            starknet: FullNodeClient,
            invoke,
            counter,
            new_account,
            class_hashes,
        ):
            prev_class = await starknet.get_class_hash_at(
                new_account.starknet_contract.address
            )
            target_class = class_hashes["account_contract_fixture"]
            assert prev_class != target_class
            assert prev_class == class_hashes["account_contract"]

            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                target_class,
            )

            await assert_counter_transaction_success(counter, new_account)

            new_class = await starknet.get_class_hash_at(
                new_account.starknet_contract.address
            )
            assert new_class == target_class
