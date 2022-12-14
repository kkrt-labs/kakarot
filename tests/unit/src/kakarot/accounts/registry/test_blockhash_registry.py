import pytest
from starkware.starknet.testing.contract import StarknetContract
from tests.integration.helpers.helpers import int_to_uint256

@pytest.mark.asyncio
class TestBlockhashRegistry:
    async def test_should_set_blockhashes(
        self, blockhash_registry: StarknetContract, kakarot: StarknetContract
    ):
        block_number = int_to_uint256(1)
        await blockhash_registry.set_blockhashes(
            block_number=[block_number],
            block_hash=[123]
        ).execute(caller_address=kakarot.contract_address)

        blockhash = (
            await blockhash_registry.get_blockhash(
                block_number
            ).call()
        )

        assert blockhash.result.blockhash == 123
