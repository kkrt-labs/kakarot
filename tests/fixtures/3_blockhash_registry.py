import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="session")
async def blockhash_registry(starknet: Starknet):
    return await starknet.deploy(
        source="./src/kakarot/registry/blockhash/blockhash_registry.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[1],
    )


@pytest_asyncio.fixture(scope="module", autouse=True)
async def set_blockhash_registry_and_blockhashes(
    kakarot: StarknetContract, blockhash_registry: StarknetContract, blockhashes: dict
):
    await blockhash_registry.transfer_ownership(kakarot.contract_address).execute(
        caller_address=1
    )
    await kakarot.set_blockhash_registry(
        blockhash_registry_address_=blockhash_registry.contract_address
    ).execute(caller_address=1)
    await blockhash_registry.set_blockhashes(
        block_number=[
            int_to_uint256(int(x)) for x in blockhashes["last_256_blocks"].keys()
        ],
        block_hash=list(blockhashes["last_256_blocks"].values()),
    ).execute(caller_address=kakarot.contract_address)
    yield
    await blockhash_registry.transfer_ownership(1).execute(
        caller_address=kakarot.contract_address
    )
