import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.uint256 import int_to_uint256


@pytest.mark.asyncio
class TestBlockhashRegistry:
    async def test_should_set_blockhashes(self, blockhash_registry: StarknetContract):
        block_number_1 = int_to_uint256(1)
        block_number_2 = int_to_uint256(2)
        block_number_3 = int_to_uint256(3)
        block_hash = [123, 456, 789]
        await blockhash_registry.set_blockhashes(
            block_number=[block_number_1, block_number_2, block_number_3],
            block_hash=block_hash,
        ).execute(caller_address=1)

        blockhash_1 = await blockhash_registry.get_blockhash(block_number_1).call()
        blockhash_2 = await blockhash_registry.get_blockhash(block_number_2).call()
        blockhash_3 = await blockhash_registry.get_blockhash(block_number_3).call()
        assert blockhash_1.result.blockhash == 123
        assert blockhash_2.result.blockhash == 456
        assert blockhash_3.result.blockhash == 789
