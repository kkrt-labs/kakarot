from typing import Callable

import pytest
import pytest_asyncio

from tests.integration.helpers.constants import MAX_INT
from tests.integration.helpers.helpers import (
    PERMIT_TYPEHASH,
    ec_sign,
    get_approval_digest,
    get_domain_separator,
)
from tests.utils.errors import kakarot_error

TOTAL_SUPPLY = 10000 * 10**18
TEST_AMOUNT = 10 * 10**18


@pytest_asyncio.fixture(scope="module")
async def token(
    deploy_solidity_contract: Callable,
    owner,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_address=owner.starknet_address,
    )


@pytest.fixture(scope="module")
async def other(others):
    return others[0]


@pytest.mark.asyncio
@pytest.mark.UniswapV2ERC20
@pytest.mark.usefixtures("starknet_snapshot")
class TestUniswapV2ERC20:
    class TestDeploy:
        async def test_should_set_constants(self, token, owner):
            name = await token.name()
            assert name == "Uniswap V2"
            assert await token.symbol() == "UNI-V2"
            assert await token.decimals() == 18
            assert await token.totalSupply() == TOTAL_SUPPLY
            assert await token.balanceOf(owner.address) == TOTAL_SUPPLY
            assert await token.DOMAIN_SEPARATOR() == get_domain_separator(
                name, token.evm_contract_address
            )
            assert await token.PERMIT_TYPEHASH() == PERMIT_TYPEHASH

    class TestApprove:
        async def test_should_set_allowance(self, token, owner, other):
            await token.approve(
                other.address,
                TEST_AMOUNT,
                caller_address=owner.starknet_address,
            )
            assert token.events.Approval == [
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": TEST_AMOUNT,
                }
            ]
            allowance = await token.allowance(owner.address, other.address)
            assert allowance == TEST_AMOUNT

    class TestTransfer:
        async def test_should_transfer_token_when_signer_is_owner(
            self, token, owner, other
        ):
            await token.transfer(
                other.address,
                TEST_AMOUNT,
                caller_address=owner.starknet_address,
            )
            assert token.events.Transfer == [
                {
                    "from": owner.address,
                    "to": other.address,
                    "value": TEST_AMOUNT,
                }
            ]
            assert await token.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token.balanceOf(other.address) == TEST_AMOUNT

        async def test_should_fail_when_amount_is_greater_than_balance_and_balance_not_zero(
            self, token, owner, other
        ):
            with kakarot_error("Kakarot: Reverted with reason: 147028384"):
                await token.transfer(
                    other.address,
                    TOTAL_SUPPLY + 1,
                    caller_address=owner.starknet_address,
                )

        async def test_should_fail_when_amount_is_greater_than_balance_and_balance_zero(
            self, token, owner, other
        ):
            with kakarot_error("Kakarot: Reverted with reason: 147028384"):
                await token.transfer(
                    owner.address,
                    1,
                    caller_address=other.starknet_address,
                )

    class TestTransferFrom:
        async def test_should_transfer_token_when_signer_is_approved(
            self, token, owner, other
        ):
            await token.approve(
                other.address,
                TEST_AMOUNT,
                caller_address=owner.starknet_address,
            )
            await token.transferFrom(
                owner.address,
                other.address,
                TEST_AMOUNT,
                caller_address=other.starknet_address,
            )
            assert token.events.Transfer == [
                {"from": owner.address, "to": other.address, "value": TEST_AMOUNT}
            ]

            assert await token.allowance(owner.address, other.address) == 0
            assert await token.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token.balanceOf(other.address) == TEST_AMOUNT

        async def test_should_transfer_token_when_signer_is_approved_max_uint(
            self, token, owner, other
        ):
            await token.approve(
                other.address,
                MAX_INT,
                caller_address=owner.starknet_address,
            )
            await token.transferFrom(
                owner.address,
                other.address,
                TEST_AMOUNT,
                caller_address=other.starknet_address,
            )
            assert token.events.Transfer == [
                {"from": owner.address, "to": other.address, "value": TEST_AMOUNT}
            ]

            assert await token.allowance(owner.address, other.address) == MAX_INT
            assert await token.balanceOf(owner.address) == TOTAL_SUPPLY - TEST_AMOUNT
            assert await token.balanceOf(other.address) == TEST_AMOUNT

    class TestPermit:
        async def test_should_update_allowance(self, token, owner, other):
            nonce = await token.nonces(owner.address)
            deadline = MAX_INT
            digest = get_approval_digest(
                "Uniswap V2",
                token.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": other.address,
                    "value": TEST_AMOUNT,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            await token.permit(
                owner.address,
                other.address,
                TEST_AMOUNT,
                deadline,
                v,
                r,
                s,
                caller_address=owner.starknet_address,
            )
            assert token.events.Approval == [
                {"owner": owner.address, "spender": other.address, "value": TEST_AMOUNT}
            ]
            assert await token.allowance(owner.address, other.address) == TEST_AMOUNT
            assert await token.nonces(owner.address) == 1
