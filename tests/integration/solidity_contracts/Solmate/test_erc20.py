import re

import pytest
from eth_utils import keccak

from tests.integration.helpers.helpers import (
    PERMIT_TYPEHASH,
    ec_sign,
    get_approval_digest,
    get_domain_separator,
)

MAX_INT = 2**256 - 1
TEST_AMOUNT_HIGH = 10**18
TEST_AMOUNT_LOW = 9 * (10**17)


@pytest.mark.asyncio
@pytest.mark.SolmateERC20
@pytest.mark.usefixtures("starknet_snapshot")
class TestERC20:
    class TestDeploy:
        async def test_should_set_name_symbol_and_decimals(self, erc_20):
            name = await erc_20.name()
            assert name == "Kakarot Token"
            symbol = await erc_20.symbol()
            assert symbol == "KKT"
            decimals = await erc_20.decimals()
            assert decimals == 18

    class TestMint:
        async def test_should_mint(self, erc_20, owner, others):
            await erc_20.mint(
                others[0].address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_AMOUNT_HIGH
            assert await erc_20.balanceOf(others[0].address) == TEST_AMOUNT_HIGH

    class TestBurn:
        async def test_should_burn(self, erc_20, owner, others):
            burn_amount = TEST_AMOUNT_LOW
            await erc_20.mint(
                others[0].address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )
            await erc_20.burn(
                others[0].address, burn_amount, caller_address=owner.starknet_address
            )
            assert await erc_20.totalSupply() == TEST_AMOUNT_HIGH - burn_amount
            assert (
                await erc_20.balanceOf(others[0].address)
                == TEST_AMOUNT_HIGH - burn_amount
            )

    class TestApprove:
        async def test_should_approve(self, erc_20, owner, others):
            assert await erc_20.approve(
                others[0].address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )
            assert (
                await erc_20.allowance(owner.address, others[0].address)
                == TEST_AMOUNT_HIGH
            )

    class TestTransfer:
        async def test_should_transfer(self, erc_20, owner, others):
            await erc_20.mint(
                owner.address, TEST_AMOUNT_HIGH, caller_address=owner.starknet_address
            )
            assert await erc_20.transfer(
                others[0].address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_AMOUNT_HIGH
            assert await erc_20.balanceOf(owner.address) == 0
            assert await erc_20.balanceOf(others[0].address) == TEST_AMOUNT_HIGH

        async def test_should_transfer_from(self, erc_20, owner, others):
            from_wallet = others[0]

            await erc_20.mint(
                from_wallet.address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )

            await erc_20.approve(
                owner.address,
                TEST_AMOUNT_HIGH,
                caller_address=from_wallet.starknet_address,
            )
            assert await erc_20.transferFrom(
                from_wallet.address,
                others[1].address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_AMOUNT_HIGH

            assert await erc_20.allowance(from_wallet.address, owner.address) == 0

            assert await erc_20.balanceOf(from_wallet.address) == 0
            assert await erc_20.balanceOf(others[1].address) == TEST_AMOUNT_HIGH

        async def test_should_transfer_from_with_infinite_approve(
            self, erc_20, owner, others
        ):
            from_wallet = others[0]

            await erc_20.mint(
                from_wallet.address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )

            await erc_20.approve(
                owner.address, MAX_INT, caller_address=from_wallet.starknet_address
            )
            assert await erc_20.transferFrom(
                from_wallet.address,
                others[1].address,
                TEST_AMOUNT_HIGH,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == TEST_AMOUNT_HIGH

            assert await erc_20.allowance(from_wallet.address, owner.address) == MAX_INT

            assert await erc_20.balanceOf(from_wallet.address) == 0
            assert await erc_20.balanceOf(others[1].address) == TEST_AMOUNT_HIGH

        async def test_transfer_should_fail_when_insufficient_balance(
            self, erc_20, owner, others
        ):
            await erc_20.mint(
                owner.address, TEST_AMOUNT_LOW, caller_address=owner.starknet_address
            )
            with pytest.raises(Exception) as e:
                await erc_20.transfer(
                    others[0].address,
                    TEST_AMOUNT_HIGH,
                    caller_address=owner.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert message == "Kakarot: Reverted with reason: 12884901888"

        async def test_transfer_from_should_fail_when_insufficient_allowance(
            self, erc_20, owner, others
        ):

            from_wallet = others[0]
            await erc_20.mint(
                owner.address, TEST_AMOUNT_HIGH, caller_address=owner.starknet_address
            )
            await erc_20.approve(
                owner.address,
                TEST_AMOUNT_LOW,
                caller_address=from_wallet.starknet_address,
            )
            with pytest.raises(Exception) as e:
                await erc_20.transferFrom(
                    from_wallet.address,
                    others[1].address,
                    TEST_AMOUNT_HIGH,
                    caller_address=owner.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert (
                message
                == "Kakarot: Reverted with reason: 228495326938605691542089934818328444928"
            )

        async def test_transfer_from_should_fail_when_insufficient_balance(
            self, erc_20, owner, others
        ):
            from_wallet = others[0]

            await erc_20.mint(
                from_wallet.address,
                TEST_AMOUNT_LOW,
                caller_address=owner.starknet_address,
            )

            await erc_20.approve(
                owner.address,
                TEST_AMOUNT_HIGH,
                caller_address=from_wallet.starknet_address,
            )
            with pytest.raises(Exception) as e:
                await erc_20.transferFrom(
                    from_wallet.address,
                    others[1].address,
                    TEST_AMOUNT_HIGH,
                    caller_address=owner.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert message == "Kakarot: Reverted with reason: 12884901888"

    class TestPermit:
        async def test_should_permit(self, erc_20, owner, others):
            nonce = await erc_20.nonces(owner.address)
            deadline = MAX_INT
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": others[0].address,
                    "value": TEST_AMOUNT_HIGH,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            await erc_20.permit(
                owner.address,
                others[0].address,
                TEST_AMOUNT_HIGH,
                deadline,
                v,
                r,
                s,
                caller_address=owner.starknet_address,
            )

            assert (
                await erc_20.allowance(owner.address, others[0].address)
                == TEST_AMOUNT_HIGH
            )
            assert await erc_20.nonces(owner.address) == 1

        async def test_permit_should_fail_with_bad_nonce(self, erc_20, owner, others):
            bad_nonce = 1
            deadline = MAX_INT
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": others[0].address,
                    "value": MAX_INT,
                },
                bad_nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            with pytest.raises(Exception) as e:
                await erc_20.permit(
                    owner.address,
                    others[0].address,
                    TEST_AMOUNT_HIGH,
                    deadline,
                    v,
                    r,
                    s,
                    caller_address=owner.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_permit_should_fail_with_bad_deadline(
            self, erc_20, blockhashes, owner, others
        ):
            nonce = await erc_20.nonces(owner.address)
            deadline = MAX_INT
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": others[0].address,
                    "value": MAX_INT,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            with pytest.raises(Exception) as e:
                await erc_20.permit(
                    owner.address,
                    others[0].address,
                    TEST_AMOUNT_HIGH,
                    deadline - 1,
                    v,
                    r,
                    s,
                    caller_address=owner.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_permit_should_fail_on_replay(self, erc_20, owner, others):
            nonce = await erc_20.nonces(owner.address)
            deadline = MAX_INT
            digest = get_approval_digest(
                "Kakarot Token",
                erc_20.evm_contract_address,
                {
                    "owner": owner.address,
                    "spender": others[0].address,
                    "value": TEST_AMOUNT_HIGH,
                },
                nonce,
                deadline,
            )
            v, r, s = ec_sign(digest, owner.private_key)
            await erc_20.permit(
                owner.address,
                others[0].address,
                TEST_AMOUNT_HIGH,
                deadline,
                v,
                r,
                s,
                caller_address=owner.starknet_address,
            )

            with pytest.raises(Exception) as e:
                await erc_20.permit(
                    owner.address,
                    others[0].address,
                    TEST_AMOUNT_HIGH,
                    deadline,
                    v,
                    r,
                    s,
                    caller_address=owner.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert message == "Kakarot: Reverted with reason: 0"
