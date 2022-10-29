from collections import namedtuple
from textwrap import wrap
from time import time

import pytest
import pytest_asyncio


@pytest_asyncio.fixture(scope="session")
async def zk_evm(starknet, eth):
    start = time()
    contract_hash = await starknet.declare(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=0,
    )
    _zk_evm = await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[1, eth.contract_address, contract_hash.class_hash],
    )
    evm_time = time()
    print(f"\nzkEVM deployed in {evm_time - start:.2f}s")
    registry = await starknet.deploy(
        source="./src/kakarot/accounts/registry/account_registry.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[_zk_evm.contract_address],
    )
    registry_time = time()
    print(f"AccountRegistry deployed in {registry_time - evm_time:.2f}s")
    await _zk_evm.set_account_registry(
        registry_address_=registry.contract_address
    ).execute(caller_address=1)
    account_time = time()
    print(f"zkEVM set in {account_time - registry_time:.2f}s")
    res = await _zk_evm.deploy(bytes=[1, 12312]).call(caller_address=1)
    print("Contract Address: ", res)
    return _zk_evm


argnames = ["contract_code", "code", "calldata", "stack", "memory", "return_value"]
Params = namedtuple("Params", argnames)

test_cases = [
    # {
    #     "params": {
    #         "contract_code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114605057007f6d4ce63c000000000000000000000000000000000000000000000000000000008114605b575b600a54600101600a55005b600a5400",
    #         "code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114604f577f6d4ce63c000000000000000000000000000000000000000000000000000000008114605a575b600a54600101600a55005b600a5400",
    #         "calldata": "371303c000000000000000000000000000000000000000000000000000000000",
    #         "stack": "",
    #         "memory": "",
    #         "return_value": "",
    #     },
    #     "id": "sstore",
    # },
    #     {
    #     "params": {
    #         "contract_code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114605057007f6d4ce63c000000000000000000000000000000000000000000000000000000008114605b575b600a54600101600a55005b600a5400",
    #         "code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114604f577f6d4ce63c000000000000000000000000000000000000000000000000000000008114605a575b600a54600101600a55005b600a5400",
    #         "calldata": "6d4ce63c00000000000000000000000000000000000000000000000000000000",
    #         "stack": "",
    #         "memory": "",
    #         "return_value": "",
    #     },
    #     "id": "sstore2",
    # },
    # {
    #     "params": {
    #         "contract_code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114605057007f6d4ce63c000000000000000000000000000000000000000000000000000000008114605b575b600a54600101600a55005b600a5400",
    #         "code": "600054",
    #         "calldata": "",
    #         "stack": "",
    #         "memory": "",
    #         "return_value": "",
    #     },
    #     "id": "sload",
    # },
    # {
    #     "params": {
    #         "contract_code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114605057007f6d4ce63c000000000000000000000000000000000000000000000000000000008114605b575b600a54600101600a55005b600a5400",
    #         "code": "602e600055600054",
    #         "calldata": "",
    #         "stack": "",
    #         "memory": "",
    #         "return_value": "",
    #     },
    #     "id": "sload",
    # },
    # {
    #     "params": {
    #         "contract_code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114605057007f6d4ce63c000000000000000000000000000000000000000000000000000000008114605b575b600a54600101600a55005b600a5400",
    #         "code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114605057007f6d4ce63c000000000000000000000000000000000000000000000000000000008114605b575b600a54600101600a55005b600a5400",
    #         "calldata": "6d4ce63c00000000000000000000000000000000000000000000000000000000",
    #         "stack": "",
    #         "memory": "",
    #         "return_value": "",
    #     },
    #     "id": "return",
    # },
]


params = [pytest.param(*Params(**case.pop("params")), **case) for case in test_cases]


@pytest.mark.asyncio
class TestZkEVM:
    @staticmethod
    def int_to_uint256(value):
        low = value & ((1 << 128) - 1)
        high = value >> 128
        return low, high

    @pytest.mark.parametrize(
        argnames,
        params,
    )
    async def test_execute_at_address(
        self,
        starknet,
        zk_evm,
        code,
        contract_code,
        calldata,
        stack,
        memory,
        return_value,
    ):
        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
        # Add right arguments
        print("Deploy Called")
        contract_address = await starknet.deploy(
            source="./src/kakarot/accounts/contract/contract_account.cairo",
            cairo_path=["src"],
            disable_hint_validation=True,
            constructor_calldata=[1, 96, *[int(m, 16) for m in wrap(contract_code, 2)]],
        )
        print("Contract Address")
        print(contract_address.contract_address)
        res = await zk_evm.execute_at_address(
            address=contract_address.contract_address,
            code=[int(m, 16) for m in wrap(code, 2)],
            calldata=[int(m, 16) for m in wrap(calldata, 2)],
        ).call(caller_address=1)
        print("Before Check")
        assert res.result.stack == [
            Uint256(*self.int_to_uint256(int(s)))
            for s in (stack.split(",") if stack else [])
        ]
        assert res.result.memory == [int(m, 16) for m in wrap(memory, 2)]

        # address: felt, calldata_len: felt, calldata: felt*
