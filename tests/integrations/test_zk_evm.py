from textwrap import wrap

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.integrations.test_cases import (
    params_erc20,
    params_execute,
    params_execute_at_address,
)
from tests.utils.utils import traceit


@pytest_asyncio.fixture(scope="module")
async def zk_evm(
    starknet: Starknet, eth: StarknetContract, contract_account_class: DeclaredClass
) -> StarknetContract:
    _zk_evm = await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
        constructor_calldata=[
            1,
            eth.contract_address,
            contract_account_class.class_hash,
        ],
    )
    _zk_evm = traceit.trace(_zk_evm, "zk_evm")
    return _zk_evm


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
    @staticmethod
    def int_to_uint256(value):
        low = value & ((1 << 128) - 1)
        high = value >> 128
        return low, high

    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(self, zk_evm: StarknetContract, params: dict, request):
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute(
                value=int(params["value"]),
                bytecode=[int(b, 16) for b in wrap(params["code"], 2)],
                calldata=[int(b, 16) for b in wrap(params["calldata"], 2)],
            ).call(caller_address=1)

        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
        assert res.result.stack == [
            Uint256(*self.int_to_uint256(int(s)))
            for s in (params["stack"].split(",") if params["stack"] else [])
        ]

        assert res.result.memory == [int(m, 16) for m in wrap(params["memory"], 2)]
        events = params.get("events")
        if events:
            assert [
                [
                    event.keys,
                    event.data,
                ]
                for event in sorted(res.call_info.events, key=lambda x: x.order)
            ] == events

    @pytest.mark.parametrize(
        "params",
        params_execute_at_address,
    )
    async def test_execute_at_address(self, zk_evm, params, request):
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute_at_address(
                address=0,
                value=0,
                calldata=[int(b, 16) for b in wrap(params["code"], 2)],
            ).execute(caller_address=1)
            evm_contract_address = res.result.evm_contract_address
            starknet_contract_address = res.result.starknet_contract_address

            await zk_evm.initiate(
                evm_address=evm_contract_address,
                starknet_address=starknet_contract_address,
                value=params["value"],
            ).execute(caller_address=1)

            res = await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=params["value"],
                calldata=[int(b, 16) for b in wrap(params["calldata"], 2)],
            ).execute(caller_address=2)

        assert res.result.return_data == [
            int(m, 16) for m in wrap(params["return_value"], 2)
        ]

    async def test_deploy(
        self,
        starknet: Starknet,
        zk_evm: StarknetContract,
        contract_account_class: DeclaredClass,
    ):
        code = [1, 12312]
        with traceit.context("deploy"):
            tx = await zk_evm.deploy(bytes=code).execute(caller_address=1)
        starknet_contract_address = tx.result.starknet_contract_address
        contract_account = StarknetContract(
            starknet.state,
            contract_account_class.abi,
            starknet_contract_address,
            tx,
        )
        assert (await contract_account.bytecode().call()).result.bytecode == code

    @pytest.mark.parametrize(
        "params",
        params_erc20,
    )
    async def test_erc20(self, zk_evm: StarknetContract, params, request):
        value = 0
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute_at_address(
                address=0,
                value=value,
                calldata=[int(b, 16) for b in wrap(params["code"], 2)],
            ).execute(caller_address=1)

            evm_contract_address = res.result.evm_contract_address
            starknet_contract_address = res.result.starknet_contract_address

            await zk_evm.initiate(
                evm_address=evm_contract_address,
                starknet_address=starknet_contract_address,
                value=value,
            ).execute(caller_address=1)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=value,
                calldata=[int(b, 16) for b in wrap(params["mint"], 2)],
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=value,
                calldata=[int(b, 16) for b in wrap(params["approve"], 2)],
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=value,
                calldata=[int(b, 16) for b in wrap(params["allowance"], 2)],
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=value,
                calldata=[int(b, 16) for b in wrap(params["transferFrom"], 2)],
            ).execute(caller_address=1)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=value,
                calldata=[int(b, 16) for b in wrap(params["transfer"], 2)],
            ).execute(caller_address=1)

            res = await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=value,
                calldata=[int(b, 16) for b in wrap(params["balanceOf"], 2)],
            ).execute(caller_address=1)

        assert res.result.return_data == [
            int(m, 16) for m in wrap(params["return_value"], 2)
        ]
