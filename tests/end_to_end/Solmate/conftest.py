import pytest_asyncio


@pytest_asyncio.fixture(scope="module")
async def from_wallet(new_eoa):
    return await new_eoa(0.1)


@pytest_asyncio.fixture(scope="module")
async def to_wallet(new_eoa):
    return await new_eoa(0.1)
