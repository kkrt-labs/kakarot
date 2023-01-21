import os
from random import randrange
from typing import Tuple

import pytest_asyncio
import web3
from eth_account.account import Account, SignedMessage
from eth_keys import keys
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
        "maxFeePerGas": 1000,
        "maxPriorityFeePerGas": 667667,
        "gas": 999999999,
        "to": bytes.fromhex("95222290dd7278aa3ddd389cc1e1d165cc4bafe5"),
        "value": 10000000000000000,
        "data": b"",
    }


@pytest_asyncio.fixture(scope="package")
async def legacy_tx() -> dict:
    return {
        "chainId": 1263227476,
        "nonce": 1,
        "gasPrice": 1000,
        "gas": 999999999,
        "to": bytes.fromhex("95222290dd7278aa3ddd389cc1e1d165cc4bafe5"),
        "value": 10000000000000000,
        "data": b"",
    }
