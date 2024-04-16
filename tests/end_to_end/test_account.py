import pytest
import pytest_asyncio
from starknet_py.net.full_node_client import FullNodeClient
from starkware.starknet.public.abi import get_storage_var_address

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
async def erc20_token(deploy_solidity_contract, new_account):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=new_account.starknet_contract,
    )


@pytest.fixture(scope="function")
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


async def assert_transfer_success(erc20_token, new_account, other):
    receipt = (
        await erc20_token.transfer(
            other.address, TEST_AMOUNT, caller_eoa=new_account.starknet_contract
        )
    )["receipt"]
    events = erc20_token.events.parse_starknet_events(receipt.events)
    assert events["Transfer"] == [
        {
            "from": new_account.address,
            "to": other.address,
            "value": TEST_AMOUNT,
        }
    ]
    assert (
        await erc20_token.balanceOf(new_account.address) == TOTAL_SUPPLY - TEST_AMOUNT
    )
    assert await erc20_token.balanceOf(other.address) == TEST_AMOUNT


@pytest.mark.asyncio(scope="session")
@pytest.mark.AccountContract
class TestAccount:
    class TestAutoUpgradeOnTransaction:
        async def test_should_upgrade_outdated_account_on_transfer(
            self,
            starknet: FullNodeClient,
            invoke,
            erc20_token,
            new_account,
            other,
            class_hashes,
            cleanup,
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

            await assert_transfer_success(erc20_token, new_account, other)

            new_class = await starknet.get_class_hash_at(
                new_account.starknet_contract.address
            )
            assert new_class == target_class

        async def test_should_update_cairo1_helpers_class(
            self,
            starknet: FullNodeClient,
            invoke,
            erc20_token,
            new_account,
            other,
            class_hashes,
            cleanup,
        ):
            prev_cairo1_helpers_class = await starknet.get_storage_at(
                new_account.starknet_contract.address,
                get_storage_var_address("Account_cairo1_helpers_class_hash"),
            )
            target_class = class_hashes["Cairo1HelpersFixture"]
            assert prev_cairo1_helpers_class != target_class
            assert prev_cairo1_helpers_class == class_hashes["Cairo1Helpers"]

            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                class_hashes["account_contract_fixture"],
            )
            await invoke("kakarot", "set_cairo1_helpers_class_hash", target_class)

            await assert_transfer_success(erc20_token, new_account, other)

            new_cairo1_helpers_class = await starknet.get_storage_at(
                new_account.starknet_contract.address,
                get_storage_var_address("Account_cairo1_helpers_class_hash"),
            )
            assert new_cairo1_helpers_class == target_class
