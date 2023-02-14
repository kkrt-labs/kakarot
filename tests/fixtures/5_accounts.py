import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def account_proxy(starknet: Starknet):
    return await starknet.declare(
        source="src/kakarot/accounts/proxy/proxy.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
