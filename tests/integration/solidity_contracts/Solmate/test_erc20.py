import pytest
import pytest_asyncio

from tests.utils.constants import MAX_INT
from tests.utils.errors import kakarot_error
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
        caller_address=owner.starknet_address,
    )


@pytest.mark.asyncio
@pytest.mark.SolmateERC20
@pytest.mark.usefixtures("starknet_snapshot")
class TestERC20:
    class TestDeploy:
        async def test_should_set_name_symbol_and_decimals(self, erc_20):
            assert await erc_20.name() == "Kakarot Token"
            assert await erc_20.symbol() == "KKT"
            assert await erc_20.decimals() == 18

    class TestMint:
        async def test_should_mint(self, erc_20, owner, other):
            await erc_20.mint(
                other.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_SUPPLY
            assert await erc_20.balanceOf(other.address) == TEST_SUPPLY

    class TestBurn:
        async def test_should_burn(self, erc_20, owner, other):
            burn_amount = TEST_AMOUNT
            await erc_20.mint(
                other.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )
            await erc_20.burn(
                other.address, burn_amount, caller_address=owner.starknet_address
            )
            assert await erc_20.totalSupply() == TEST_SUPPLY - burn_amount
            assert await erc_20.balanceOf(other.address) == TEST_SUPPLY - burn_amount

    class TestApprove:
        async def test_should_approve(self, erc_20, owner, other):
            assert await erc_20.approve(
                other.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.allowance(owner.address, other.address) == TEST_SUPPLY

    class TestTransfer:
        async def test_should_transfer(self, erc_20, owner, other):
            await erc_20.mint(
                owner.address, TEST_SUPPLY, caller_address=owner.starknet_address
            )
            assert await erc_20.transfer(
                other.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_SUPPLY
            assert await erc_20.balanceOf(owner.address) == 0
            assert await erc_20.balanceOf(other.address) == TEST_SUPPLY

        async def test_transfer_should_fail_when_insufficient_balance(
            self, erc_20, owner, other
        ):
            await erc_20.mint(
                owner.address, TEST_AMOUNT, caller_address=owner.starknet_address
            )
            with kakarot_error():
                await erc_20.transfer(
                    other.address,
                    TEST_SUPPLY,
                    caller_address=owner.starknet_address,
                )

    class TestTransferFrom:
        async def test_should_transfer_from(self, erc_20, owner, others):
            from_wallet = others[0]
            to_wallet = others[1]

            await erc_20.mint(
                from_wallet.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )

            await erc_20.approve(
                owner.address,
                TEST_SUPPLY,
                caller_address=from_wallet.starknet_address,
            )
            assert await erc_20.transferFrom(
                from_wallet.address,
                to_wallet.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_SUPPLY

            assert await erc_20.allowance(from_wallet.address, owner.address) == 0

            assert await erc_20.balanceOf(from_wallet.address) == 0
            assert await erc_20.balanceOf(to_wallet.address) == TEST_SUPPLY

        async def test_should_transfer_from_with_infinite_approve(
            self, erc_20, owner, others
        ):
            from_wallet = others[0]
            to_wallet = others[1]

            await erc_20.mint(
                from_wallet.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )

            await erc_20.approve(
                owner.address, MAX_INT, caller_address=from_wallet.starknet_address
            )
            assert await erc_20.transferFrom(
                from_wallet.address,
                to_wallet.address,
                TEST_SUPPLY,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_SUPPLY

            assert await erc_20.allowance(from_wallet.address, owner.address) == MAX_INT

            assert await erc_20.balanceOf(from_wallet.address) == 0
            assert await erc_20.balanceOf(others[1].address) == TEST_SUPPLY

        async def test_transfer_from_should_fail_when_insufficient_allowance(
            self, erc_20, owner, other, others
        ):
            await erc_20.mint(
                other.address, TEST_SUPPLY, caller_address=owner.starknet_address
            )
            await erc_20.approve(
                owner.address,
                TEST_AMOUNT,
                caller_address=other.starknet_address,
            )
            with kakarot_error():
                await erc_20.transferFrom(
                    other.address,
                    others[1].address,
                    TEST_SUPPLY,
                    caller_address=owner.starknet_address,
                )

        async def test_transfer_from_should_fail_when_insufficient_balance(
            self, erc_20, owner, other, others
        ):
            await erc_20.mint(
                other.address,
                TEST_AMOUNT,
                caller_address=owner.starknet_address,
            )

            await erc_20.approve(
                owner.address,
                TEST_SUPPLY,
                caller_address=other.starknet_address,
            )
            with kakarot_error():
                await erc_20.transferFrom(
                    other.address,
                    others[1].address,
                    TEST_SUPPLY,
                    caller_address=owner.starknet_address,
                )

    class TestPermit:
        async def test_should_permit(self, blockhashes, erc_20, owner, other):
            nonce = await erc_20.nonces(owner.address)
            deadline = blockhashes["current_block"]["timestamp"]
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
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
                caller_address=owner.starknet_address,
            )

            assert await erc_20.allowance(owner.address, other.address) == TEST_SUPPLY
            assert await erc_20.nonces(owner.address) == 1

        async def test_permit_should_fail_with_bad_nonce(
            self, blockhashes, erc_20, owner, other
        ):
            bad_nonce = 1
            deadline = blockhashes["current_block"]["timestamp"]
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": MAX_INT,
                },
                bad_nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            with kakarot_error("INVALID_SIGNER"):
                await erc_20.permit(
                    owner.address,
                    other.address,
                    TEST_SUPPLY,
                    deadline,
                    v,
                    r,
                    s,
                    caller_address=owner.starknet_address,
                )

        async def test_permit_should_fail_with_bad_deadline(
            self, erc_20, blockhashes, owner, other
        ):
            nonce = await erc_20.nonces(owner.address)
            deadline = blockhashes["current_block"]["timestamp"]
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": MAX_INT,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            with kakarot_error("PERMIT_DEADLINE_EXPIRED"):
                await erc_20.permit(
                    owner.address,
                    other.address,
                    TEST_SUPPLY,
                    deadline - 1,
                    v,
                    r,
                    s,
                    caller_address=owner.starknet_address,
                )

        async def test_permit_should_fail_on_replay(
            self, blockhashes, erc_20, owner, other
        ):
            nonce = await erc_20.nonces(owner.address)
            deadline = blockhashes["current_block"]["timestamp"]
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
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
                caller_address=owner.starknet_address,
            )

            with kakarot_error("INVALID_SIGNER"):
                await erc_20.permit(
                    owner.address,
                    other.address,
                    TEST_SUPPLY,
                    deadline,
                    v,
                    r,
                    s,
                    caller_address=owner.starknet_address,
                )
