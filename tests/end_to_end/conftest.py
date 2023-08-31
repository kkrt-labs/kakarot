import logging
import subprocess
from collections import namedtuple
from functools import partial
from typing import List, Union

import pytest
import pytest_asyncio
from eth_utils.address import to_checksum_address
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account

from tests.utils.helpers import generate_random_private_key

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

Wallet = namedtuple("Wallet", ["address", "private_key", "starknet_contract"])


@pytest.fixture(scope="session")
def max_fee():
    """
    max_fee is just hard coded to 0.01 to make sure it passes
    it is not used per se in the test
    """
    return int(1e16)


@pytest.fixture(scope="session", autouse=True)
def starknet():
    """
    End-to-end tests assume that there is already a "Starknet" network running
    with kakarot deployed.
    We return the RPC_CLIENT in a fixture to avoid importing in the test the scripts.utils
    but gather instead in fixtures all the utils.

    Since this `starknet` fixture is run before all the others, setting the STARKNET_NETWORK
    environment variable here would effectively change the target network of the test suite.
    """
    from scripts.constants import RPC_CLIENT

    return RPC_CLIENT


@pytest_asyncio.fixture(scope="session")
async def addresses() -> List[Wallet]:
    """
    Returns a list of addresses to be used in tests.
    Addresses are returned as named tuples with
    - address: the hex string of the EVM address (20 bytes)
    - starknet_address: the corresponding address for starknet (same value but as int)
    """
    from scripts.utils.kakarot import get_eoa

    wallets = []
    for i in range(2):
        private_key = generate_random_private_key(seed=i)
        wallets.append(
            Wallet(
                address=int(private_key.public_key.to_address(), 16),
                private_key=private_key,
                starknet_contract=await get_eoa(private_key),
            )
        )
    return wallets


@pytest_asyncio.fixture(scope="session")
async def deployer() -> Account:
    """
    Using a fixture with scope=session let us cache this function and make the test run faster
    """

    from scripts.utils.starknet import get_starknet_account

    return await get_starknet_account()


@pytest_asyncio.fixture(scope="session")
async def eth(deployer) -> Contract:
    """
    Using a fixture with scope=session let us cache this function and make the test run faster
    """

    from scripts.utils.starknet import get_eth_contract

    return await get_eth_contract(provider=deployer)


@pytest.fixture(scope="session")
def fund_starknet_address(deployer, eth):
    """
    Using a fixture with scope=session let us cache this function and make the test run faster
    """

    from scripts.utils.starknet import fund_address

    return partial(fund_address, funding_account=deployer, token_contract=eth)


@pytest_asyncio.fixture(scope="session")
async def kakarot(deployer) -> Contract:
    """
    Using a fixture with scope=session let us cache this function and make the test run faster
    """
    from scripts.utils.starknet import get_contract

    return await get_contract("kakarot", provider=deployer)


@pytest_asyncio.fixture(scope="session")
async def deploy_fee(kakarot: Contract) -> int:
    """
    Using a fixture with scope=session let us cache this function and make the test run faster
    """
    return (await kakarot.functions["get_deploy_fee"].call()).deploy_fee


@pytest.fixture(scope="session")
def compute_starknet_address(kakarot: Contract):
    """
    A fixture just for easing the call and make the tests smaller
    """

    async def _factory(evm_address: Union[int, str]):
        if isinstance(evm_address, str):
            evm_address = int(evm_address, 16)
        return (
            await kakarot.functions["compute_starknet_address"].call(evm_address)
        ).contract_address

    return _factory


@pytest.fixture(scope="session")
def deploy_externally_owned_account(kakarot: Contract, max_fee: int):
    """
    A fixture just for easing the call and make the tests smaller
    """

    async def _factory(evm_address: Union[int, str]):
        if isinstance(evm_address, str):
            evm_address = int(evm_address, 16)
        tx = await kakarot.functions["deploy_externally_owned_account"].invoke(
            evm_address, max_fee=max_fee
        )
        await tx.wait_for_acceptance()
        return tx

    return _factory


@pytest.fixture(scope="session")
def get_contract(deployer):
    """
    A fixture just for easing the call and make the tests smaller
    """
    from scripts.utils.starknet import get_contract

    async def _factory(contract_name, address=None, provider=deployer):
        return await get_contract(
            contract_name=contract_name,
            address=address,
            provider=provider,
        )

    return _factory


@pytest.fixture(scope="session")
def ethBalanceOf(eth: Contract, compute_starknet_address):
    """
    A fixture to get the balance of an address.
    Accept both EVM and Starknet address, int or hex str
    """

    async def _factory(address: Union[int, str]):
        try:
            evm_address = to_checksum_address(address)
            address = await compute_starknet_address(evm_address)
        except:
            address = address if isinstance(address, int) else int(address, 16)

        return (await eth.functions["balanceOf"].call(address)).balance

    return _factory
