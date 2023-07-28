import pytest_asyncio


@pytest_asyncio.fixture(scope="session")
def counter_deployer(addresses):
    return addresses[1]


@pytest_asyncio.fixture(scope="session")
def caller_deployer(addresses):
    return addresses[2]


@pytest_asyncio.fixture(scope="session")
def plain_opcodes_deployer(addresses):
    return addresses[3]


@pytest_asyncio.fixture(scope="session")
def safe_deployer(addresses):
    return addresses[4]


@pytest_asyncio.fixture(scope="package")
async def counter(deploy_solidity_contract, counter_deployer):
    return await deploy_solidity_contract(
        "PlainOpcodes", "Counter", caller_eoa=counter_deployer
    )


@pytest_asyncio.fixture(scope="package")
async def caller(deploy_solidity_contract, caller_deployer):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "Caller",
        caller_eoa=caller_deployer,
    )


@pytest_asyncio.fixture(scope="package")
async def plain_opcodes(deploy_solidity_contract, plain_opcodes_deployer, counter):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "PlainOpcodes",
        counter.evm_contract_address,
        caller_eoa=plain_opcodes_deployer,
    )


@pytest_asyncio.fixture(scope="package")
async def safe(deploy_solidity_contract, safe_deployer):
    return await deploy_solidity_contract(
        "PlainOpcodes", "Safe", caller_eoa=safe_deployer
    )
