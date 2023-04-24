import pytest_asyncio


@pytest_asyncio.fixture(scope="module")
async def counter(deploy_solidity_contract, owner):
    return await deploy_solidity_contract("PlainOpcodes", "Counter", caller_eoa=owner)


@pytest_asyncio.fixture(scope="module")
async def caller(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "Caller",
        caller_eoa=owner,
    )


@pytest_asyncio.fixture(scope="module")
async def plain_opcodes(deploy_solidity_contract, owner, counter):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "PlainOpcodes",
        counter.evm_contract_address,
        caller_eoa=owner,
    )
