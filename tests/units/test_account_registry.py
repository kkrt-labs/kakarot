import random

import pytest
from starkware.starknet.testing.contract import StarknetContract

random.seed(0)


@pytest.mark.asyncio
class TestAccountRegistry:
    async def test_should_set_starknet_and_evm_addresses(
        self, account_registry: StarknetContract
    ):
        starknet_address = random.randint(0, 10_000)
        evm_address = random.randint(0, 10_000)
        await account_registry.set_account_entry(starknet_address, evm_address).execute(
            caller_address=1
        )
        stored_starknet_address = await account_registry.get_starknet_address(
            evm_address
        ).call()
        assert stored_starknet_address.result.starknet_address == starknet_address
        stored_evm_address = await account_registry.get_evm_address(
            starknet_address
        ).call()
        assert stored_evm_address.result.evm_address == evm_address
