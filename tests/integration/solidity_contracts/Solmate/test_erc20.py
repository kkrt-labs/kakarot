import pytest

from tests.utils.reporting import traceit


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
            amount = int(1e18)
            await erc_20.mint(
                others[0].address, amount, caller_address=owner.starknet_address
            )
            assert await erc_20.totalSupply() == amount
            assert await erc_20.balanceOf(others[0].address) == amount

    class TestBurn:
        async def test_should_burn(self, erc_20, owner, others):
            amount = int(1e18)
            burn_amount = int(0.9e18)
            await erc_20.mint(
                others[0].address, amount, caller_address=owner.starknet_address
            )
            await erc_20.burn(
                others[0].address, burn_amount, caller_address=owner.starknet_address
            )
            assert await erc_20.totalSupply() == amount - burn_amount
            assert await erc_20.balanceOf(others[0].address) == amount - burn_amount

    class TestApprove:
        async def test_should_approve(self, erc_20, owner, others):
            amount = int(1e18)
            assert await erc_20.approve(
                others[0].address, amount, caller_address=owner.starknet_address
            )
            assert await erc_20.allowance(owner.address, others[0].address) == amount

    class TestTransfer:
        async def test_should_transfer(self, erc_20, owner, others):
            amount = int(1e18)
            await erc_20.mint(
                owner.address, amount, caller_address=owner.starknet_address
            )
            assert await erc_20.transfer(
                others[0].address, amount, caller_address=owner.starknet_address
            )
            assert await erc_20.totalSupply() == amount
            assert await erc_20.balanceOf(owner.address) == 0
            assert await erc_20.balanceOf(others[0].address) == amount

    class TestTransferFrom:
        async def test_should_transfer_from(self, erc_20, owner, others):
            from_address = others[0]

            amount = int(1e18)
            await erc_20.mint(
                from_address.address, amount, caller_address=owner.starknet_address
            )

            await erc_20.approve(
                owner.address, amount, caller_address=from_address.starknet_address
            )
            assert await erc_20.transferFrom(
                from_address.address,
                others[1].address,
                amount,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == amount

            assert await erc_20.allowance(from_address.address, owner.address) == 0

            assert await erc_20.balanceOf(from_address.address) == 0
            assert await erc_20.balanceOf(others[1].address) == amount

        async def test_should_transfer_from_with_infinite_approve(
            self, erc_20, owner, others
        ):
            from_address = others[0]
            uint256_max = 2**256 - 1
            amount = int(1e18)
            await erc_20.mint(
                from_address.address, amount, caller_address=owner.starknet_address
            )

            await erc_20.approve(
                owner.address, uint256_max, caller_address=from_address.starknet_address
            )
            assert await erc_20.transferFrom(
                from_address.address,
                others[1].address,
                amount,
                caller_address=owner.starknet_address,
            )
            assert await erc_20.totalSupply() == amount

            assert (
                await erc_20.allowance(from_address.address, owner.address)
                == uint256_max
            )

            assert await erc_20.balanceOf(from_address.address) == 0
            assert await erc_20.balanceOf(others[1].address) == amount
