import random

import pytest
from starkware.starknet.testing.contract import StarknetContract

random.seed(0)


@pytest.mark.asyncio
class TestAccountRegistry:
    async def test_should_set_starknet_and_evm_contract_addresses(
        self, account_registry: StarknetContract
    ):
        starknet_contract_address = random.randint(0, 10_000)
        evm_contract_address = random.randint(0, 10_000)
        await account_registry.set_account_entry(
            starknet_contract_address, evm_contract_address
        ).execute(caller_address=1)
        stored_starknet_contract_address = (
            await account_registry.get_starknet_contract_address(
                evm_contract_address
            ).call()
        )
        assert (
            stored_starknet_contract_address.result.starknet_contract_address
            == starknet_contract_address
        )
        stored_evm_contract_address = await account_registry.get_evm_contract_address(
            starknet_contract_address
        ).call()
        assert (
            stored_evm_contract_address.result.evm_contract_address
            == evm_contract_address
        )
