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

    async def test_should_mint_approve_and_transfer(
        self, erc_20, owner, others, request
    ):
        with traceit.context(request.node.own_markers[0].name):

            # Mint few token to others[0]
            await erc_20.mint(
                others[0].address,
                356,
                caller_address=owner.starknet_contract.contract_address,
            )
            assert await erc_20.totalSupply() == 356
            assert await erc_20.balanceOf(others[0].address) == 356

            # others[0] approves others[1] to spend some
            await erc_20.approve(
                others[1].address,
                10,
                caller_address=others[0].starknet_contract.contract_address,
            )
            assert await erc_20.allowance(others[0].address, others[1].address) == 10

            # others[1] sends others[0] token to themselves
            await erc_20.transferFrom(
                others[0].address,
                others[1].address,
                10,
                caller_address=others[1].starknet_contract.contract_address,
            )
            assert await erc_20.balanceOf(others[0].address) == 356 - 10
            assert await erc_20.balanceOf(others[1].address) == 10

            # others[1] sends token to others[2]
            await erc_20.transfer(
                others[2].address,
                1,
                caller_address=others[1].starknet_contract.contract_address,
            )
            assert await erc_20.balanceOf(others[1].address) == 10 - 1
            assert await erc_20.balanceOf(others[2].address) == 1
