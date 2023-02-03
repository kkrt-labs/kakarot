import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def externally_owned_account_class(starknet: Starknet):
    return await starknet.declare(
        source="src/kakarot/accounts/eoa/aa/externally_owned_account.cairo",
        cairo_path=["src"],
    )


@pytest_asyncio.fixture(scope="package")
async def deployer(
    starknet: Starknet, externally_owned_account_class, kakarot
) -> StarknetContract:
    deployer = await starknet.deploy(
        source="src/kakarot/accounts/eoa/deployer/deployer.cairo",
        cairo_path=["src"],
        constructor_calldata=[
            externally_owned_account_class.class_hash,
            kakarot.contract_address,
        ],
    )

    return deployer


@pytest_asyncio.fixture(scope="package")
async def default_tx() -> dict:
    return {
        "nonce": 1,
        "chainId": 1263227476,
        "maxFeePerGas": 30549100000000000,
        "maxPriorityFeePerGas": 20000000000,
        "gas": 21000,
        "to": bytes.fromhex("95222290dd7278aa3ddd389cc1e1d165cc4bafe5"),
        "value": 10000000000000000,
        "data": b"",
    }


@pytest_asyncio.fixture(scope="package")
async def legacy_tx() -> dict:
    return {
        "chainId": 1263227476,
        "nonce": 1,
        "gasPrice": 14000000000,
        "gas": 21000,
        "to": bytes.fromhex("95222290dd7278aa3ddd389cc1e1d165cc4bafe5"),
        "value": 10000000000000000,
        "data": b"",
    }
