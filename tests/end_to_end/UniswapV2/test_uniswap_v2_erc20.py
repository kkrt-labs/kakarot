import pytest

from tests.utils.constants import MAX_INT
from tests.utils.errors import evm_error
from tests.utils.helpers import (
    PERMIT_TYPEHASH,
    ec_sign,
    get_approval_digest,
    get_domain_separator,
)

TOTAL_SUPPLY = 10000 * 10**18
TEST_AMOUNT = 10 * 10**18


@pytest.mark.asyncio
@pytest.mark.UniswapV2ERC20
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
                name, token_a.address
            )
            assert await token_a.PERMIT_TYPEHASH() == PERMIT_TYPEHASH

    class TestApprove:
        async def test_should_set_allowance(self, token_a, owner, other):
            receipt = await token_a.approve(
                other.address, TEST_AMOUNT, caller_eoa=owner.starknet_contract
            )
            events = token_a.events.parse_starknet_events(receipt.events)
            assert events["Approval"] == [
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
            receipt = await token_a.transfer(
                other.address, TEST_AMOUNT, caller_eoa=owner.starknet_contract
            )
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

        async def test_should_fail_when_amount_is_greater_than_balance_and_balance_not_zero(
            self, token_a, owner, other
        ):
            with evm_error():
                await token_a.transfer(
                    other.address, TOTAL_SUPPLY + 1, caller_eoa=owner.starknet_contract
                )

        async def test_should_fail_when_amount_is_greater_than_balance_and_balance_zero(
            self, token_a, owner, other
        ):
            with evm_error():
                await token_a.transfer(
                    owner.address, 1, caller_eoa=other.starknet_contract
                )

    class TestTransferFrom:
        async def test_should_transfer_token_when_signer_is_approved(
            self, token_a, owner, other
        ):
            await token_a.approve(
                other.address, TEST_AMOUNT, caller_eoa=owner.starknet_contract
            )
            receipt = await token_a.transferFrom(
                owner.address,
                other.address,
                TEST_AMOUNT,
                caller_eoa=other.starknet_contract,
            )
            events = token_a.events.parse_starknet_events(receipt.events)
            assert events["Transfer"] == [
                {"from": owner.address, "to": other.address, "value": TEST_AMOUNT}
            ]

            assert await token_a.allowance(owner.address, other.address) == 0
            assert await token_a.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token_a.balanceOf(other.address) == TEST_AMOUNT

        async def test_should_transfer_token_when_signer_is_approved_max_uint(
            self, token_a, owner, other
        ):
            await token_a.approve(
                other.address, MAX_INT, caller_eoa=owner.starknet_contract
            )
            receipt = await token_a.transferFrom(
                owner.address,
                other.address,
                TEST_AMOUNT,
                caller_eoa=other.starknet_contract,
            )
            events = token_a.events.parse_starknet_events(receipt.events)
            assert events["Transfer"] == [
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
                token_a.address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": TEST_AMOUNT,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            receipt = await token_a.permit(
                owner.address,
                other.address,
                TEST_AMOUNT,
                deadline,
                v,
                r,
                s,
                caller_eoa=owner.starknet_contract,
            )
            events = token_a.events.parse_starknet_events(receipt.events)
            assert events["Approval"] == [
                {"owner": owner.address, "spender": other.address, "value": TEST_AMOUNT}
            ]
            assert await token_a.allowance(owner.address, other.address) == TEST_AMOUNT
            assert await token_a.nonces(owner.address) == 1
