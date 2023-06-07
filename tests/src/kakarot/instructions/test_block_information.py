import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="module")
async def block_information(
    starknet: Starknet, blockhashes: dict, blockhash_registry: StarknetContract
):
    block_number = max(blockhashes["last_256_blocks"].keys())
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_block_information.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            *int_to_uint256(int(block_number)),
            blockhashes["last_256_blocks"][block_number],
            blockhash_registry.contract_address,
        ],
    )


@pytest.mark.asyncio
class TestBlockInformation:
    async def test_everything_block(self, block_information):
        await block_information.test__blockhash_should_push_blockhash_to_stack().call()
        await block_information.test__chainId__should_push_chain_id_to_stack().call()
        await block_information.test__coinbase_should_push_coinbase_address_to_stack().call()
        await block_information.test__timestamp_should_push_block_timestamp_to_stack().call()
        await block_information.test__number_should_push_block_number_to_stack().call()
        await block_information.test__gaslimit_should_push_gaslimit_to_stack().call()
        await block_information.test__difficulty_should_push_difficulty_to_stack().call()
        await block_information.test__basefee_should_push_basefee_to_stack().call()
