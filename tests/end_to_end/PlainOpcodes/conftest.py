import pytest_asyncio


@pytest_asyncio.fixture(scope="package")
async def counter(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "PlainOpcodes",
        "Counter",
        caller_eoa=owner.starknet_contract,
    )
