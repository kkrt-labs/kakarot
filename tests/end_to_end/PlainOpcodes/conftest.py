import pytest_asyncio


@pytest_asyncio.fixture(scope="package")
async def counter(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "Counter",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def caller(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "Caller",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def plain_opcodes(deploy_solidity_contract, counter, owner):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "PlainOpcodes",
        counter.address,
        caller_eoa=owner.starknet_contract,
    )
