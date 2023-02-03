import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def account_proxy(starknet: Starknet):
    return await starknet.declare(
        source="src/kakarot/accounts/proxy/proxy.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="package")
async def default_tx() -> dict:
    return {
        "nonce": 1,
        "chainId": 1263227476,
        "maxFeePerGas": 1000,
        "maxPriorityFeePerGas": 667667,
        "gas": 999999999,
        "to": bytes.fromhex("95222290dd7278aa3ddd389cc1e1d165cc4bafe5"),
        "value": 10000000000000000,
        "data": b"",
    }
