import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def contract_account_class(starknet: Starknet) -> DeclaredClass:
    return await starknet.declare(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="session")
async def externally_owned_account_class(starknet: Starknet):
    return await starknet.declare(
        source="src/kakarot/accounts/eoa/externally_owned_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="session")
async def account_proxy_class(starknet: Starknet):
    return await starknet.declare(
        source="src/kakarot/accounts/proxy/proxy.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
