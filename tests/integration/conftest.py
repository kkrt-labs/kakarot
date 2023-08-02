from collections import namedtuple
from typing import List

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.accounts import fund_evm_address
from tests.utils.constants import DEPLOY_FEE
from tests.utils.helpers import generate_random_private_key, private_key_from_hex

Wallet = namedtuple(
    "Wallet", ["address", "private_key", "starknet_contract", "starknet_address"]
)


@pytest_asyncio.fixture(scope="session")
async def kakarot(
    starknet: Starknet,
    eth: StarknetContract,
    contract_account_class: DeclaredClass,
    externally_owned_account_class: DeclaredClass,
    account_proxy_class: DeclaredClass,
    blockhash_registry: StarknetContract,
) -> StarknetContract:
    owner = 1
    class_hash = await starknet.deprecated_declare(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    kakarot = await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            owner,  # owner
            eth.contract_address,  # native_token_address_
            contract_account_class.class_hash,  # contract_account_class_hash_
            externally_owned_account_class.class_hash,  # externally_owned_account_class_hash
            account_proxy_class.class_hash,  # account_proxy_class_hash
            DEPLOY_FEE,
        ],
    )
    await kakarot.set_blockhash_registry(
        blockhash_registry_address_=blockhash_registry.contract_address
    ).execute(caller_address=owner)
    return kakarot


@pytest_asyncio.fixture(scope="session")
async def addresses(
    starknet, kakarot, externally_owned_account_class, eth
) -> List[Wallet]:
    """
    Returns a list of addresses to be used in tests.
    Addresses are returned as named tuples with
    - address: the hex string of the EVM address (20 bytes)
    - starknet_address: the corresponding address for starknet (same value but as int)
    """
    # Predefined private key shared with anvil,
    # so we can more easily compare results for validity
    predefined_private_key = private_key_from_hex(
        "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    )

    # Randomly generated private keys
    private_keys = [predefined_private_key] + [
        generate_random_private_key(seed=i) for i in range(15)
    ]

    wallets = []
    for private_key in private_keys:
        evm_address = private_key.public_key.to_checksum_address()

        # pre fund account so that fees can be paid back to deployer
        await fund_evm_address(int(evm_address, 16), kakarot, eth)

        eoa_deploy_tx = await kakarot.deploy_externally_owned_account(
            int(evm_address, 16)
        ).execute(caller_address=5)

        wallets.append(
            Wallet(
                address=evm_address,
                private_key=private_key,
                starknet_contract=StarknetContract(
                    starknet.state,
                    externally_owned_account_class.abi,
                    eoa_deploy_tx.call_info.internal_calls[0].contract_address,
                    eoa_deploy_tx,
                ),
                starknet_address=eoa_deploy_tx.call_info.internal_calls[
                    0
                ].contract_address,
            )
        )
    return wallets


@pytest_asyncio.fixture(scope="session")
async def owner(addresses):
    return addresses[0]


@pytest_asyncio.fixture(scope="session")
async def others(addresses):
    return addresses[1:]


@pytest.fixture(scope="session")
async def other(others):
    return others[0]
