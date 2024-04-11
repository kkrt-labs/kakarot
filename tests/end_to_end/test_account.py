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
async def erc20_token(deploy_solidity_contract, new_account):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=new_account.starknet_contract,
    )


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
        ):
            # Given an initial class
            prev_class = await starknet.get_class_hash_at(
                new_account.starknet_contract.address
            )
            target_class = class_hashes["account_contract_fixture"]
            assert prev_class != target_class
            assert prev_class == class_hashes["account_contract"]

            # When setting the account class to version `account_contract_fixture`
            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                target_class,
            )

            # Then the account should process the next transaction and be upgraded to the new class
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
                await erc20_token.balanceOf(new_account.address)
                == TOTAL_SUPPLY - TEST_AMOUNT
            )
            assert await erc20_token.balanceOf(other.address) == TEST_AMOUNT

            new_class = await starknet.get_class_hash_at(
                new_account.starknet_contract.address
            )
            assert new_class == target_class

            # Reset the account class to the previous version
            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                prev_class,
            )
