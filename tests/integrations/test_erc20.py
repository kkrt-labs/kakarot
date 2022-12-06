from typing import Callable

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.reporting import traceit


@pytest.mark.asyncio
@pytest.mark.SolmateERC20
class TestERC20:
    class TestDeploy:
        async def test_should_set_name_symbol_and_decimals(
            self,
            deploy_solidity_contract: Callable,
        ):
            erc_20 = await deploy_solidity_contract(
                "ERC20", "Kakarot Token", "KKT", 18, caller_address=1
            )
            name = await erc_20.name()
            assert name == "Kakarot Token"
            symbol = await erc_20.symbol()
            assert symbol == "KKT"
            decimals = await erc_20.decimals()
            assert decimals == 18

    async def test_should_mint_approve_and_transfer(
        self, kakarot: StarknetContract, deploy_solidity_contract: Callable, request
    ):
        state = kakarot.state.copy()
        caller_addresses = list(range(4))
        addresses = ["0x" + "0" * 39 + str(i) for i in caller_addresses]
        erc_20 = await deploy_solidity_contract(
            "ERC20", "Kakarot Token", "KKT", 18, caller_address=1
        )
        with traceit.context(request.node.own_markers[0].name):

            await erc_20.mint(addresses[2], 356, caller_address=caller_addresses[1])

            total_supply = await erc_20.totalSupply()
            assert total_supply == 356

            await erc_20.approve(
                addresses[1], 1000000, caller_address=caller_addresses[2]
            )

            allowance = await erc_20.allowance(addresses[2], addresses[1])
            assert allowance == 1000000

            balances_before = [await erc_20.balanceOf(address) for address in addresses]

            await erc_20.transferFrom(
                addresses[2], addresses[1], 10, caller_address=caller_addresses[1]
            )
            balances_after = [await erc_20.balanceOf(address) for address in addresses]

            assert balances_after[0] - balances_before[0] == 0
            assert balances_after[1] - balances_before[1] == 10
            assert balances_after[2] - balances_before[2] == -10
            assert balances_after[3] - balances_before[3] == 0

            balances_before = balances_after

            await erc_20.transfer(addresses[3], 0x5, caller_address=caller_addresses[1])
            balances_after = [await erc_20.balanceOf(address) for address in addresses]

            assert balances_after[0] - balances_before[0] == 0
            assert balances_after[1] - balances_before[1] == -5
            assert balances_after[2] - balances_before[2] == 0
            assert balances_after[3] - balances_before[3] == 5
        kakarot.state = state
