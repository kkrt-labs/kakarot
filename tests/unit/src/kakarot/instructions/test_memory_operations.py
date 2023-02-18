import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def memory_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/instructions/test_memory_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestMemoryOperations:
    async def test_everything_memory(self, memory_operations):
        [
            await memory_operations.test__exec_pc__should_update_after_incrementing(
                increment=x
            ).call()
            for x in range(1, 15)
        ]
        await memory_operations.test__exec_pop_should_pop_an_item_from_execution_context().call()
        await memory_operations.test__exec_mload_should_load_a_value_from_memory().call()
        await memory_operations.test__exec_mload_should_load_a_value_from_memory_with_memory_expansion().call()
        await memory_operations.test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize().call()
        await memory_operations.test__exec_gas_should_return_remaining_gas().call()

        a @ pytest.mark.asyncio


class TestMemoryJhnn:
    async def test__exec_sstore_jhnn(
        self,
        memory_operations,
        contract_account,
        kakarot,
        account_registry,
    ):
        random.seed(0)
        bytecode = [random.randint(0, 255) for _ in range(32)]

        contract_account = await contract_account.write_bytecode(bytecode).execute(
            caller_address=1
        )

        starknet_contract_address = contract_account.call_info.contract_address
        evm_contract_address = 1

        await account_registry.set_account_entry(
            starknet_contract_address, evm_contract_address
        ).execute(caller_address=kakarot.contract_address)

        await memory_operations.test__exec_sstore_jhnn(
            account_registry_address=account_registry.contract_address,
            evm_contract_address=evm_contract_address,
            registry_address_=account_registry.contract_address,
        ).execute(caller_address=starknet_contract_address)
