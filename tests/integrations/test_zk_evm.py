import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.integrations.test_cases import params_execute, params_execute_at_address
from tests.utils.utils import (
    get_contract,
    hex_string_to_bytes_array,
    int_to_uint256,
    traceit,
    wrap_for_kakarot,
)


@pytest_asyncio.fixture(scope="module")
async def zk_evm(
    starknet: Starknet, eth: StarknetContract, contract_account_class: DeclaredClass
) -> StarknetContract:
    return await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
        constructor_calldata=[
            1,
            eth.contract_address,
            contract_account_class.class_hash,
        ],
    )


@pytest_asyncio.fixture(scope="module", autouse=True)
async def set_account_registry(
    zk_evm: StarknetContract, account_registry: StarknetContract
):
    await account_registry.transfer_ownership(zk_evm.contract_address).execute(
        caller_address=1
    )
    await zk_evm.set_account_registry(
        registry_address_=account_registry.contract_address
    ).execute(caller_address=1)
    yield
    await account_registry.transfer_ownership(1).execute(
        caller_address=zk_evm.contract_address
    )


@pytest.mark.asyncio
class TestZkEVM:
    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(self, zk_evm: StarknetContract, params: dict, request):
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute(
                value=int(params["value"]),
                bytecode=hex_string_to_bytes_array(params["code"]),
                calldata=hex_string_to_bytes_array(params["calldata"]),
            ).call(caller_address=1)

        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
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

    @pytest_asyncio.fixture(scope="module")
    async def erc_20(self, zk_evm: StarknetContract) -> dict:
        ERC20 = get_contract("ERC20")
        deploy_bytecode = hex_string_to_bytes_array(
            ERC20.constructor("name", "symbol", 18).data_in_transaction
        )

        with traceit.context("deploy kakarot erc20"):
            tx = await zk_evm.deploy(bytecode=deploy_bytecode).execute(caller_address=1)

        return {
            "contract": wrap_for_kakarot(ERC20, zk_evm, tx.result.evm_contract_address),
            "tx": tx,
        }

    @pytest.mark.skip(
        "One byte is different, should investigate after resolving the other skipped tests"
    )
    async def test_deploy(
        self,
        starknet: Starknet,
        erc_20: dict,
        contract_account_class: DeclaredClass,
    ):
        starknet_contract_address = erc_20["tx"].result.starknet_contract_address
        contract_account = StarknetContract(
            starknet.state,
            contract_account_class.abi,
            starknet_contract_address,
            erc_20["tx"],
        )
        stored_bytecode = (await contract_account.bytecode().call()).result.bytecode
        contract_bytecode = hex_string_to_bytes_array(erc_20["contract"].bytecode.hex())
        deployed_bytecode = contract_bytecode[contract_bytecode.index(0xFE) + 1 :]
        assert stored_bytecode == deployed_bytecode
        name = await erc_20["contract"].name()
        assert name == "name"
        symbol = await erc_20["contract"].symbol()
        assert symbol == "symbol"
        decimals = await erc_20["contract"].decimals()
        assert decimals == 18

    @pytest.mark.parametrize(
        "params",
        params_execute_at_address,
    )
    async def test_execute_at_address(
        self,
        zk_evm: StarknetContract,
        erc_20: dict,
        params: dict,
        request,
    ):
        state = zk_evm.state.copy()
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute_at_address(
                address=erc_20["tx"].result.evm_contract_address,
                value=params["value"],
                calldata=hex_string_to_bytes_array(params["calldata"]),
            ).execute(caller_address=2)

        assert res.result.return_data == hex_string_to_bytes_array(
            params["return_value"]
        )
        zk_evm.state = state

    @pytest.mark.SolmateERC20
    async def test_erc20(self, zk_evm: StarknetContract, erc_20: dict, request):
        state = zk_evm.state.copy()
        caller_addresses = list(range(4))
        addresses = ["0x" + "0" * 39 + str(i) for i in caller_addresses]
        with traceit.context(request.node.own_markers[0].name):

            await erc_20["contract"].mint(
                addresses[2], 0x164, caller_address=caller_addresses[1]
            )

            total_supply = await erc_20["contract"].totalSupply()
            assert total_supply == 0x164

            await erc_20["contract"].approve(
                addresses[1], 0xF4240, caller_address=caller_addresses[2]
            )

            allowance = await erc_20["contract"].allowance(addresses[2], addresses[1])
            assert allowance == 0xF4240

            balances_before = [
                await erc_20["contract"].balanceOf(address) for address in addresses
            ]

            await erc_20["contract"].transferFrom(
                addresses[2], addresses[1], 0xA, caller_address=caller_addresses[1]
            )
            balances_after = [
                await erc_20["contract"].balanceOf(address) for address in addresses
            ]

            assert balances_after[0] - balances_before[0] == 0
            assert balances_after[1] - balances_before[1] == 0xA
            assert balances_after[2] - balances_before[2] == -0xA
            assert balances_after[3] - balances_before[3] == 0

            balances_before = balances_after

            await erc_20["contract"].transfer(
                addresses[3], 0x5, caller_address=caller_addresses[1]
            )
            balances_after = [
                await erc_20["contract"].balanceOf(address) for address in addresses
            ]

            assert balances_after[0] - balances_before[0] == 0
            assert balances_after[1] - balances_before[1] == -0x5
            assert balances_after[2] - balances_before[2] == 0
            assert balances_after[3] - balances_before[3] == 0x5

        zk_evm.state = state
