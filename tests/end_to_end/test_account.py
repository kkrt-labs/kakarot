import pytest
import pytest_asyncio

from kakarot_scripts.utils.starknet import call

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
async def token_a(
    deploy_solidity_contract,
    owner,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=owner.starknet_contract,
    )


@pytest.mark.asyncio(scope="session")
@pytest.mark.AccountContract
class TestAccount:
    class TestAutoUpgradeOnTransaction:
        async def test_should_upgrade_outdated_account_on_transfer(
            self, invoke, token_a, owner, other, class_hashes
        ):
            # Given an initial version of 1000
            prev_version = (await call(owner.starknet_contract.address, "version"))[0]
            assert prev_version == 1000  # 000.001.000

            # When setting the account class to version 001.000.000
            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                class_hashes["account_contract_fixture"],
            )

            # Then the account should process the next transaction and be upgraded to the new version.
            receipt = (
                await token_a.transfer(
                    other.address, TEST_AMOUNT, caller_eoa=owner.starknet_contract
                )
            )["receipt"]
            events = token_a.events.parse_starknet_events(receipt.events)
            assert events["Transfer"] == [
                {
                    "from": owner.address,
                    "to": other.address,
                    "value": TEST_AMOUNT,
                }
            ]
            assert await token_a.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token_a.balanceOf(other.address) == TEST_AMOUNT

            new_version = (await call(owner.starknet_contract.address, "version"))[0]
            assert new_version == 1000000  # 001.000.000
