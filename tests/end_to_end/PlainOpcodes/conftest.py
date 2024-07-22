import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="package")
async def counter(owner):
    return await deploy("PlainOpcodes", "Counter", caller_eoa=owner.starknet_contract)


@pytest_asyncio.fixture(scope="package")
async def caller(owner):
    return await deploy("PlainOpcodes", "Caller", caller_eoa=owner.starknet_contract)


@pytest_asyncio.fixture(scope="package")
async def plain_opcodes(counter, owner):
    return await deploy(
        "PlainOpcodes",
        "PlainOpcodes",
        counter.address,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def revert_on_fallbacks(owner):
    return await deploy(
        "PlainOpcodes",
        "ContractRevertOnFallbackAndReceive",
        caller_eoa=owner.starknet_contract,
    )
