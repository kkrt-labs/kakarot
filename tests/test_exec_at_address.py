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


argnames = ["contract_code", "calldata", "stack", "memory", "return_value"]
Params = namedtuple("Params", argnames)

test_cases = [
    {
        "params": {
            "contract_code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114604f577f6d4ce63c000000000000000000000000000000000000000000000000000000008114605a575b600a54600101600a55005b600a5400",
            "calldata": "371303c000000000000000000000000000000000000000000000000000000000",
            "stack": "24910802647859241127409114343308891693497142153707997329506107691490485469184",
            "memory": "",
            "return_value": "",
        },
        "id": "contract_call_function_SSTORE",
    },
    {
        "params": {
            "contract_code": "6000357f371303c0000000000000000000000000000000000000000000000000000000008114604f577f6d4ce63c000000000000000000000000000000000000000000000000000000008114605a575b600a54600101600a55005b600a5400",
            "calldata": "6d4ce63c00000000000000000000000000000000000000000000000000000000",
            "stack": "49437969891755755400450161744656089009884903607872082989584577758955590123520,0",
            "memory": "",
            "return_value": "",
        },
        "id": "contract_call_function_SLOAD",
    },
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
        zk_evm,
        contract_code,
        calldata,
        stack,
        memory,
        return_value,
    ):
        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
        # Add right arguments
        print("Deploy Called")
        tx = await zk_evm.deploy(
            bytes=[int(b, 16) for b in wrap(contract_code, 2)],
        ).execute(caller_address=1)
        evm_contract_address = tx.result.evm_contract_address

        print("Contract Address")
        print(evm_contract_address)

        res = await zk_evm.execute_at_address(
            address=evm_contract_address,
            calldata=[int(m, 16) for m in wrap(calldata, 2)],
        ).call(caller_address=1)
        print("Before Check")
        assert res.result.stack == [
            Uint256(*self.int_to_uint256(int(s)))
            for s in (stack.split(",") if stack else [])
        ]
        assert res.result.memory == [int(m, 16) for m in wrap(memory, 2)]

    # async def test_execute_at_address(
    #     self, zk_evm, code, calldata, stack, memory, return_value
    # ):
    #     Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
    #     tx = await zk_evm.deploy(
    #         bytes=[int(b, 16) for b in wrap(code, 2)],
    #     ).execute(caller_address=1)
    #     evm_contract_address = tx.result.evm_contract_address

    #     res = await zk_evm.execute_at_address(
    #         address=evm_contract_address,
    #         calldata=[int(b, 16) for b in wrap(calldata, 2)],
    #     ).execute(caller_address=1)
    #     assert res.result.stack == [
    #         Uint256(*self.int_to_uint256(int(s)))
    #         for s in (stack.split(",") if stack else [])
    #     ]
    #     assert res.result.memory == [int(m, 16) for m in wrap(memory, 2)]
