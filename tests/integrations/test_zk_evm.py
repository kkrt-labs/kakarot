import json
from pathlib import Path
from textwrap import wrap

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet
from web3 import Web3

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
    @staticmethod
    def int_to_uint256(value):
        low = value & ((1 << 128) - 1)
        high = value >> 128
        return low, high

    @staticmethod
    def hex_string_to_bytes_array(h: str):
        if len(h) % 2 != 0:
            raise ValueError(f"Provided string has an odd length {len(h)}")
        return [int(b, 16) for b in wrap(h, 2)]

    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(self, zk_evm: StarknetContract, params: dict, request):
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute(
                value=int(params["value"]),
                bytecode=self.hex_string_to_bytes_array(params["code"]),
                calldata=self.hex_string_to_bytes_array(params["calldata"]),
            ).call(caller_address=1)

        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
        assert res.result.stack == [
            Uint256(*self.int_to_uint256(int(s)))
            for s in (params["stack"].split(",") if params["stack"] else [])
        ]

        assert res.result.memory == self.hex_string_to_bytes_array(params["memory"])
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
        solidity_output_path = Path("tests") / "solidity_files" / "output"
        abi = json.load(open(solidity_output_path / "ERC20.abi"))
        bytecode = (solidity_output_path / "ERC20.bin").read_text()
        w3 = Web3()
        ERC20 = w3.eth.contract(abi=abi, bytecode=bytecode)
        deploy_bytecode = self.hex_string_to_bytes_array(
            ERC20.constructor("name", "symbol", 18).data_in_transaction[2:]
        )

        with traceit.context("deploy kakarot erc20"):
            tx = await zk_evm.deploy(bytecode=deploy_bytecode).execute(caller_address=1)
        return {
            "contract": ERC20,
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
        contract_bytecode = self.hex_string_to_bytes_array(
            erc_20["contract"].bytecode.hex()[2:]
        )
        deployed_bytecode = contract_bytecode[contract_bytecode.index(0xFE) + 1 :]
        assert stored_bytecode == deployed_bytecode

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
                calldata=self.hex_string_to_bytes_array(params["calldata"]),
            ).execute(caller_address=2)

        assert res.result.return_data == self.hex_string_to_bytes_array(
            params["return_value"]
        )
        zk_evm.state = state

    @pytest.mark.parametrize(
        "params",
        params_erc20,
    )
    async def test_erc20(self, zk_evm: StarknetContract, erc_20: dict, params, request):
        evm_contract_address = erc_20["tx"].result.evm_contract_address
        state = zk_evm.state.copy()
        with traceit.context(request.node.callspec.id):

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["mint"]),
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["approve"]),
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["allowance"]),
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["transferFrom"]),
            ).execute(caller_address=1)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["transfer"]),
            ).execute(caller_address=1)

            res = await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["balanceOf"]),
            ).execute(caller_address=1)

        assert res.result.return_data == self.hex_string_to_bytes_array(
            params["return_value"]
        )
        zk_evm.state = state
