import pytest

from tests.integration.solidity_contracts.UniswapV2.conftest import TOTAL_SUPPLY
from tests.utils.constants import MAX_INT
from tests.utils.errors import kakarot_error
from tests.utils.helpers import (
    PERMIT_TYPEHASH,
    ec_sign,
    get_approval_digest,
    get_domain_separator,
)

TEST_AMOUNT = 10 * 10**18


@pytest.mark.asyncio
@pytest.mark.UniswapV2ERC20
@pytest.mark.usefixtures("starknet_snapshot")
class TestUniswapV2ERC20:
    class TestDeploy:
        async def test_should_set_constants(self, token_a, owner):
            name = await token_a.name()
            assert name == "Uniswap V2"
            assert await token_a.symbol() == "UNI-V2"
            assert await token_a.decimals() == 18
            assert await token_a.totalSupply() == TOTAL_SUPPLY
            assert await token_a.balanceOf(owner.address) == TOTAL_SUPPLY
            assert await token_a.DOMAIN_SEPARATOR() == get_domain_separator(
                name, token_a.evm_contract_address
            )
            assert await token_a.PERMIT_TYPEHASH() == PERMIT_TYPEHASH

    class TestApprove:
        async def test_should_set_allowance(self, token_a, owner, other):
            await token_a.approve(
                other.address,
                TEST_AMOUNT,
                caller_address=owner.starknet_address,
            )
            assert token_a.events.Approval == [
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": TEST_AMOUNT,
                }
            ]
            allowance = await token_a.allowance(owner.address, other.address)
            assert allowance == TEST_AMOUNT

    class TestTransfer:
        async def test_should_transfer_token_when_signer_is_owner(
            self, token_a, owner, other
        ):
            await token_a.transfer(
                other.address,
                TEST_AMOUNT,
                caller_address=owner.starknet_address,
            )
            assert token_a.events.Transfer == [
                {
                    "from": owner.address,
                    "to": other.address,
                    "value": TEST_AMOUNT,
                }
            ]
            assert await token_a.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token_a.balanceOf(other.address) == TEST_AMOUNT

        async def test_should_fail_when_amount_is_greater_than_balance_and_balance_not_zero(
            self, token_a, owner, other
        ):
            with kakarot_error():
                await token_a.transfer(
                    other.address,
                    TOTAL_SUPPLY + 1,
                    caller_address=owner.starknet_address,
                )

        async def test_should_fail_when_amount_is_greater_than_balance_and_balance_zero(
            self, token_a, owner, other
        ):
            with kakarot_error():
                await token_a.transfer(
                    owner.address,
                    1,
                    caller_address=other.starknet_address,
                )

    class TestTransferFrom:
        async def test_should_transfer_token_when_signer_is_approved(
            self, token_a, owner, other
        ):
            await token_a.approve(
                other.address,
                TEST_AMOUNT,
                caller_address=owner.starknet_address,
            )
            await token_a.transferFrom(
                owner.address,
                other.address,
                TEST_AMOUNT,
                caller_address=other.starknet_address,
            )
            assert token_a.events.Transfer == [
                {"from": owner.address, "to": other.address, "value": TEST_AMOUNT}
            ]

            assert await token_a.allowance(owner.address, other.address) == 0
            assert await token_a.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token_a.balanceOf(other.address) == TEST_AMOUNT

        async def test_should_transfer_token_when_signer_is_approved_max_uint(
            self, token_a, owner, other
        ):
            await token_a.approve(
                other.address,
                MAX_INT,
                caller_address=owner.starknet_address,
            )
            await token_a.transferFrom(
                owner.address,
                other.address,
                TEST_AMOUNT,
                caller_address=other.starknet_address,
            )
            assert token_a.events.Transfer == [
                {"from": owner.address, "to": other.address, "value": TEST_AMOUNT}
            ]

            assert await token_a.allowance(owner.address, other.address) == MAX_INT
            assert await token_a.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token_a.balanceOf(other.address) == TEST_AMOUNT

    class TestPermit:
        async def test_should_update_allowance(self, token_a, owner, other):
            nonce = await token_a.nonces(owner.address)
            deadline = MAX_INT
            digest = get_approval_digest(
                "Uniswap V2",
                token_a.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": TEST_AMOUNT,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            await token_a.permit(
                owner.address,
                other.address,
                TEST_AMOUNT,
                deadline,
                v,
                r,
                s,
                caller_address=owner.starknet_address,
            )
            assert token_a.events.Approval == [
                {"owner": owner.address, "spender": other.address, "value": TEST_AMOUNT}
            ]
            assert await token_a.allowance(owner.address, other.address) == TEST_AMOUNT
            assert await token_a.nonces(owner.address) == 1
