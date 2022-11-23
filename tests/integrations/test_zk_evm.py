from typing import Callable

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.integrations.test_cases import params_execute
from tests.utils.utils import (
    hex_string_to_bytes_array,
    int_to_uint256,
    hex_string_to_felt_packed_array,
    bytecode_len,
    traceit,
)


@pytest.mark.asyncio
class TestZkEVM:
    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(self, kakarot: StarknetContract, params: dict, request):
        with traceit.context(request.node.callspec.id):
            res = await kakarot.execute(
                value=int(params["value"]),
                bytecode=hex_string_to_felt_packed_array(params["code"]),
                original_bytecode_len=bytecode_len(params["code"]),
                calldata=hex_string_to_felt_packed_array(params["calldata"]),
                original_calldata_len=bytecode_len(params["calldata"]),
            ).call(caller_address=1)

        Uint256 = kakarot.struct_manager.get_contract_struct("Uint256")
        assert res.result.stack == [
            Uint256(*int_to_uint256(int(s)))
            for s in (params["stack"].split(",") if params["stack"] else [])
        ]

        assert res.result.memory == hex_string_to_bytes_array(params["memory"])
        events = params.get("events")
        if events:
            assert [
                [
                    event.keys,
                    event.data,
                ]
                for event in sorted(res.call_info.events, key=lambda x: x.order)
            ] == events

    @pytest.mark.skip(
        "One byte is different, should investigate after resolving the other skipped tests"
    )
    async def test_deploy_erc20(
        self,
        deploy_solidity_contract: Callable,
    ):
        erc_20 = await deploy_solidity_contract(
            "ERC20", "Kakarot Token", "KKT", 18, caller_address=1
        )
        stored_bytecode = (
            await erc_20.contract_account.bytecode().call()
        ).result.bytecode
        contract_bytecode = hex_string_to_bytes_array(erc_20.bytecode.hex())
        deployed_bytecode = contract_bytecode[contract_bytecode.index(0xFE) + 1 :]
        assert stored_bytecode == deployed_bytecode
        name = await erc_20.name()
        assert name == "Kakarot Token"
        symbol = await erc_20.symbol()
        assert symbol == "KKT"
        decimals = await erc_20.decimals()
        assert decimals == 18

    async def test_deploy_erc721(
        self,
        deploy_solidity_contract: Callable,
    ):
        erc_721 = await deploy_solidity_contract(
            "ERC721", "Kakarot NFT", "KKNFT", caller_address=1
        )
        stored_bytecode = (
            await erc_721.contract_account.bytecode().call()
        ).result.bytecode
        contract_bytecode = hex_string_to_bytes_array(erc_721.bytecode.hex())
        deployed_bytecode = contract_bytecode[contract_bytecode.index(0xFE) + 1 :]
        assert stored_bytecode == deployed_bytecode
        name = await erc_721.name()
        assert name == "Kakarot NFT"
        symbol = await erc_721.symbol()
        assert symbol == "KKNFT"

    @pytest.mark.SolmateERC20
    async def test_erc20(
        self, kakarot: StarknetContract, deploy_solidity_contract: Callable, request
    ):
        state = kakarot.state.copy()
        caller_addresses = list(range(4))
        addresses = ["0x" + "0" * 39 + str(i) for i in caller_addresses]
        print("CALLING DEPLOY")
        erc_20 = await deploy_solidity_contract(
            "ERC20", "Kakarot Token", "KKT", 18, caller_address=1
        )
        with traceit.context(request.node.own_markers[0].name):

            await erc_20.mint(addresses[2], 0x164, caller_address=caller_addresses[1])

            # total_supply = await erc_20.totalSupply()
            # assert total_supply == 0x164

            await erc_20.approve(
                addresses[1], 0xF4240, caller_address=caller_addresses[2]
            )

            allowance = await erc_20.allowance(addresses[2], addresses[1])
            assert allowance == 0xF4240

            balances_before = [await erc_20.balanceOf(address) for address in addresses]

            await erc_20.transferFrom(
                addresses[2], addresses[1], 0xA, caller_address=caller_addresses[1]
            )
            balances_after = [await erc_20.balanceOf(address) for address in addresses]

            assert balances_after[0] - balances_before[0] == 0
            assert balances_after[1] - balances_before[1] == 0xA
            assert balances_after[2] - balances_before[2] == -0xA
            assert balances_after[3] - balances_before[3] == 0

            balances_before = balances_after

            await erc_20.transfer(addresses[3], 0x5, caller_address=caller_addresses[1])
            balances_after = [await erc_20.balanceOf(address) for address in addresses]

            assert balances_after[0] - balances_before[0] == 0
            assert balances_after[1] - balances_before[1] == -0x5
            assert balances_after[2] - balances_before[2] == 0
            assert balances_after[3] - balances_before[3] == 0x5
        kakarot.state = state
