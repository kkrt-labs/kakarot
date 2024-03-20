import pytest
import pytest_asyncio

from tests.utils.constants import MAX_INT
from tests.utils.errors import evm_error
from tests.utils.helpers import ec_sign, get_approval_digest

TEST_SUPPLY = 10**18
TEST_AMOUNT = int(0.9 * 10**18)


@pytest_asyncio.fixture(scope="module")
async def erc_20(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "ERC20",
        "Kakarot Token",
        "KKT",
        18,
        caller_eoa=owner.starknet_contract,
    )


@pytest.mark.asyncio(scope="session")
@pytest.mark.SolmateERC20
class TestERC20:
    class TestDeploy:
        async def test_should_set_name_symbol_and_decimals(self, erc_20):
            assert await erc_20.name() == "Kakarot Token"
            assert await erc_20.symbol() == "KKT"
            assert await erc_20.decimals() == 18

    class TestMint:
        async def test_should_mint(self, erc_20, owner, other):
            total_supply_before = await erc_20.totalSupply()
            balance_before = await erc_20.balanceOf(other.address)

            await erc_20.mint(
                other.address, TEST_SUPPLY, caller_eoa=owner.starknet_contract
            )

            total_supply_after = await erc_20.totalSupply()
            balance_after = await erc_20.balanceOf(other.address)

            assert total_supply_after - total_supply_before == TEST_SUPPLY
            assert balance_after - balance_before == TEST_SUPPLY

    class TestBurn:
        async def test_should_burn(self, erc_20, owner, other):
            await erc_20.mint(
                other.address, TEST_SUPPLY, caller_eoa=owner.starknet_contract
            )

            total_supply_before = await erc_20.totalSupply()
            balance_before = await erc_20.balanceOf(other.address)

            await erc_20.burn(
                other.address, TEST_SUPPLY, caller_eoa=owner.starknet_contract
            )

            total_supply_after = await erc_20.totalSupply()
            balance_after = await erc_20.balanceOf(other.address)

            assert total_supply_before - total_supply_after == TEST_SUPPLY
            assert balance_before - balance_after == TEST_SUPPLY

    class TestApprove:
        async def test_should_approve(self, erc_20, owner, other):
            allowance_before = await erc_20.allowance(owner.address, other.address)

            assert await erc_20.approve(
                other.address, TEST_SUPPLY, caller_eoa=owner.starknet_contract
            )

            allowance_after = await erc_20.allowance(owner.address, other.address)

            assert allowance_after - allowance_before == TEST_SUPPLY

    class TestTransfer:
        async def test_should_transfer(self, erc_20, owner, other):
            await erc_20.mint(
                owner.address, TEST_SUPPLY, caller_eoa=owner.starknet_contract
            )

            balance_sender_before = await erc_20.balanceOf(owner.address)
            balance_receiver_before = await erc_20.balanceOf(other.address)

            assert await erc_20.transfer(
                other.address,
                TEST_SUPPLY,
                caller_eoa=owner.starknet_contract,
            )

            balance_sender_after = await erc_20.balanceOf(owner.address)
            balance_receiver_after = await erc_20.balanceOf(other.address)

            assert balance_sender_before - balance_sender_after == TEST_SUPPLY
            assert balance_receiver_after - balance_receiver_before == TEST_SUPPLY

        async def test_transfer_should_fail_when_insufficient_balance(
            self, erc_20, owner, other
        ):
            await erc_20.mint(
                owner.address, TEST_AMOUNT, caller_eoa=owner.starknet_contract
            )
            balance_sender_before = await erc_20.balanceOf(owner.address)
            with evm_error():
                await erc_20.transfer(
                    other.address,
                    balance_sender_before + 1,
                    caller_eoa=owner.starknet_contract,
                )

    class TestTransferFrom:
        @pytest.mark.parametrize(
            "initial_allowance, final_allowance", ((TEST_SUPPLY, 0), (MAX_INT, MAX_INT))
        )
        async def test_should_transfer_and_update_allowance(
            self, erc_20, owner, others, initial_allowance, final_allowance
        ):
            from_wallet = others[0]
            to_wallet = others[1]

            await erc_20.mint(
                from_wallet.address,
                TEST_SUPPLY,
                caller_eoa=owner.starknet_contract,
            )

            balance_sender_before = await erc_20.balanceOf(from_wallet.address)
            balance_receiver_before = await erc_20.balanceOf(to_wallet.address)

            await erc_20.approve(
                owner.address,
                initial_allowance,
                caller_eoa=from_wallet.starknet_contract,
            )
            assert await erc_20.transferFrom(
                from_wallet.address,
                to_wallet.address,
                TEST_SUPPLY,
                caller_eoa=owner.starknet_contract,
            )

            balance_sender_after = await erc_20.balanceOf(from_wallet.address)
            balance_receiver_after = await erc_20.balanceOf(to_wallet.address)

            assert (
                await erc_20.allowance(from_wallet.address, owner.address)
                == final_allowance
            )
            assert balance_sender_before - balance_sender_after == TEST_SUPPLY
            assert balance_receiver_after - balance_receiver_before == TEST_SUPPLY

        async def test_transfer_from_should_fail_when_insufficient_allowance(
            self, erc_20, owner, other, others
        ):
            await erc_20.mint(
                other.address, TEST_SUPPLY, caller_eoa=owner.starknet_contract
            )
            await erc_20.approve(
                owner.address, TEST_AMOUNT, caller_eoa=other.starknet_contract
            )
            with evm_error():
                await erc_20.transferFrom(
                    other.address,
                    others[1].address,
                    TEST_SUPPLY,
                    caller_eoa=owner.starknet_contract,
                )

        async def test_transfer_from_should_fail_when_insufficient_balance(
            self, erc_20, owner, other, others
        ):
            await erc_20.mint(
                other.address, TEST_AMOUNT, caller_eoa=owner.starknet_contract
            )
            balance_other = await erc_20.balanceOf(other.address)
            await erc_20.approve(
                owner.address, balance_other + 1, caller_eoa=other.starknet_contract
            )
            with evm_error():
                await erc_20.transferFrom(
                    other.address,
                    others[1].address,
                    balance_other + 1,
                    caller_eoa=owner.starknet_contract,
                )

    class TestPermit:
        async def test_should_permit(self, erc_20, owner, other):
            nonce = await erc_20.nonces(owner.address)
            deadline = 2**256 - 1
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": TEST_SUPPLY,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            receipt = (
                await erc_20.permit(
                    owner.address,
                    other.address,
                    TEST_SUPPLY,
                    deadline,
                    v,
                    r,
                    s,
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]
            events = erc_20.events.parse_starknet_events(receipt.events)

            assert events["Approval"] == [
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "amount": TEST_SUPPLY,
                }
            ]
            assert await erc_20.allowance(owner.address, other.address) == TEST_SUPPLY
            assert await erc_20.nonces(owner.address) == 1

        async def test_permit_should_fail_with_bad_nonce(self, erc_20, owner, other):
            bad_nonce = 1
            deadline = 2**256 - 1
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": MAX_INT,
                },
                bad_nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            with evm_error("INVALID_SIGNER"):
                await erc_20.permit(
                    owner.address,
                    other.address,
                    TEST_SUPPLY,
                    deadline,
                    v,
                    r,
                    s,
                    caller_eoa=owner.starknet_contract,
                )

        async def test_permit_should_fail_with_bad_deadline(
            self, erc_20, block_with_tx_hashes, owner, other
        ):
            nonce = await erc_20.nonces(owner.address)
            pending_timestamp = block_with_tx_hashes("pending")["timestamp"]
            deadline = pending_timestamp - 1
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": MAX_INT,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            with evm_error("PERMIT_DEADLINE_EXPIRED"):
                await erc_20.permit(
                    owner.address,
                    other.address,
                    TEST_SUPPLY,
                    deadline - 1,
                    v,
                    r,
                    s,
                    caller_eoa=owner.starknet_contract,
                )

        async def test_permit_should_fail_on_replay(self, erc_20, owner, other):
            nonce = await erc_20.nonces(owner.address)
            deadline = 2**256 - 1
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": TEST_SUPPLY,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            await erc_20.permit(
                owner.address,
                other.address,
                TEST_SUPPLY,
                deadline,
                v,
                r,
                s,
                caller_eoa=owner.starknet_contract,
            )

            with evm_error("INVALID_SIGNER"):
                await erc_20.permit(
                    owner.address,
                    other.address,
                    TEST_SUPPLY,
                    deadline,
                    v,
                    r,
                    s,
                    caller_eoa=owner.starknet_contract,
                )
