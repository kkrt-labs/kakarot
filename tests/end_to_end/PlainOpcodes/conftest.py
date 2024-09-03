import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="package")
async def counter(deployer_kakarot):
    return await deploy(
        "PlainOpcodes", "Counter", caller_eoa=deployer_kakarot.starknet_contract
    )


@pytest_asyncio.fixture(scope="package")
async def caller(deployer_kakarot):
    return await deploy(
        "PlainOpcodes", "Caller", caller_eoa=deployer_kakarot.starknet_contract
    )


@pytest_asyncio.fixture(scope="package")
async def plain_opcodes(counter, deployer_kakarot):
    return await deploy(
        "PlainOpcodes",
        "PlainOpcodes",
        counter.address,
        caller_eoa=deployer_kakarot.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def revert_on_fallbacks(deployer_kakarot):
    return await deploy(
        "PlainOpcodes",
        "ContractRevertOnFallbackAndReceive",
        caller_eoa=deployer_kakarot.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def safe(deployer_kakarot):
    return await deploy(
        "PlainOpcodes", "Safe", caller_eoa=deployer_kakarot.starknet_contract
    )
