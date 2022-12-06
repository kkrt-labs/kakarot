import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def account_registry(starknet: Starknet):
    return await starknet.deploy(
        source="./src/kakarot/accounts/registry/account_registry.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[1],
    )


@pytest_asyncio.fixture(scope="package", autouse=True)
async def set_account_registry(
    kakarot: StarknetContract, account_registry: StarknetContract
):
    await account_registry.transfer_ownership(kakarot.contract_address).execute(
        caller_address=1
    )
    await kakarot.set_account_registry(
        registry_address_=account_registry.contract_address
    ).execute(caller_address=1)
    yield
    await account_registry.transfer_ownership(1).execute(
        caller_address=kakarot.contract_address
    )
