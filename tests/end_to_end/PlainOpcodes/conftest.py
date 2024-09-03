import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="package")
async def counter(new_eoa):
    deployer = await new_eoa(0.1)
    return await deploy(
        "PlainOpcodes", "Counter", caller_eoa=deployer.starknet_contract
    )


@pytest_asyncio.fixture(scope="package")
async def caller(new_eoa):
    deployer = await new_eoa(0.1)
    return await deploy("PlainOpcodes", "Caller", caller_eoa=deployer.starknet_contract)


@pytest_asyncio.fixture(scope="package")
async def plain_opcodes(counter, new_eoa):
    deployer = await new_eoa(0.1)
    return await deploy(
        "PlainOpcodes",
        "PlainOpcodes",
        counter.address,
        caller_eoa=deployer.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def revert_on_fallbacks(new_eoa):
    deployer = await new_eoa(0.1)
    return await deploy(
        "PlainOpcodes",
        "ContractRevertOnFallbackAndReceive",
        caller_eoa=deployer.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def safe(new_eoa):
    deployer = await new_eoa(0.1)
    return await deploy("PlainOpcodes", "Safe", caller_eoa=deployer.starknet_contract)
