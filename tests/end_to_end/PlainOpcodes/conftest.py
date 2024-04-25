import pytest_asyncio


@pytest_asyncio.fixture(scope="package")
async def counter(deploy_contract, owner):
    return await deploy_contract(
        "PlainOpcodes",
        "Counter",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def caller(deploy_contract, owner):
    return await deploy_contract(
        "PlainOpcodes",
        "Caller",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def plain_opcodes(deploy_contract, counter, owner):
    return await deploy_contract(
        "PlainOpcodes",
        "PlainOpcodes",
        counter.address,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def revert_on_fallbacks(deploy_contract, owner):
    return await deploy_contract(
        "PlainOpcodes",
        "ContractRevertOnFallbackAndReceive",
        caller_eoa=owner.starknet_contract,
    )
