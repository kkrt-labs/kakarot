import pytest_asyncio


@pytest_asyncio.fixture(scope="module")
async def from_wallet(new_eoa):
    return await new_eoa()


@pytest_asyncio.fixture(scope="module")
async def to_wallet(new_eoa):
    return await new_eoa()
