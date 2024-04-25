import pytest_asyncio


@pytest_asyncio.fixture(scope="package")
async def gas_sponsor_invoker(deploy_contract, owner):
    return await deploy_contract(
        "EIP3074",
        "GasSponsorInvoker",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="package")
async def sender_recorder(deploy_contract, owner):
    return await deploy_contract(
        "EIP3074",
        "SenderRecorder",
        caller_eoa=owner.starknet_contract,
    )
