import logging
from collections import namedtuple
from typing import Optional, Union

import pytest
import pytest_asyncio
from eth_keys.datatypes import PrivateKey
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account

from kakarot_scripts.constants import RPC_CLIENT, NetworkType
from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.kakarot import eth_balance_of
from kakarot_scripts.utils.kakarot import get_contract as get_solidity_contract
from kakarot_scripts.utils.kakarot import get_deployments, get_eoa
from kakarot_scripts.utils.starknet import (
    RelayerPool,
    call,
    get_contract,
    get_eth_contract,
)
from tests.utils.helpers import generate_random_private_key

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

Wallet = namedtuple("Wallet", ["address", "private_key", "starknet_contract"])


@pytest.fixture(scope="session")
def default_fee():
    """
    Return max fee hardcoded to 0 ETH. This allows to
    set the allowed number of execute steps to whatever is passed
    when launching Katana.
    """
    from kakarot_scripts.constants import NETWORK

    if NETWORK["type"] is NetworkType.DEV:
        return int(0)
    else:
        return int(1e16)


@pytest.fixture(scope="session")
def max_fee():
    """
    Return max fee hardcoded to 0.5 ETH to make sure tx passes
    it is not used per se in the test.
    """
    return int(5e17)


@pytest_asyncio.fixture(scope="session")
async def deployer(worker_id) -> Account:
    """
    Return a cached version of the deployer contract.
    """

    return await RelayerPool.get(abs(hash(worker_id)))


@pytest_asyncio.fixture(scope="session")
async def new_eoa(deployer, worker_id) -> Wallet:
    """
    Return a factory to create a new EOA with enough ETH to pass ~100 tx by default.
    """

    deployed = []

    async def _factory(amount=0):

        private_key: PrivateKey = generate_random_private_key()
        wallet = Wallet(
            address=private_key.public_key.to_checksum_address(),
            private_key=private_key,
            starknet_contract=await get_eoa(private_key, amount=amount),
        )
        logger.info(
            f"Created new EOA for worker {worker_id} with address {wallet.address}"
        )
        deployed.append(wallet)
        return wallet

    yield _factory

    coinbase = await get_solidity_contract(
        "Kakarot",
        "Coinbase",
        address=get_deployments()["Coinbase"]["address"],
    )
    gas_price = (await call("kakarot", "get_base_fee")).base_fee
    gas_limit = 40_000
    tx_cost = gas_limit * gas_price
    for wallet in deployed:
        balance = await eth_balance_of(wallet.address)
        if balance < tx_cost:
            continue

        # Send the funds to the coinbase contract. The owner will be able to withdraw them.
        await coinbase.w3.eth.send_transaction(
            caller_eoa=wallet.starknet_contract,
            value=balance - tx_cost,
            gas_limit=gas_limit,
            gas_price=gas_price,
        )

    # Withdraw the funds to the deployer
    await coinbase.functions["withdraw(uint256)"](
        toStarknetAddress=deployer.address,
        gas_limit=gas_limit,
        gas_price=gas_price,
    )


@pytest_asyncio.fixture(scope="session")
async def owner(new_eoa):
    """
    Return the main caller of all tests.
    """
    return await new_eoa(0.1)


@pytest_asyncio.fixture(scope="module")
async def other(new_eoa):
    """
    Just another EOA.
    """
    return await new_eoa(0.1)


@pytest_asyncio.fixture(scope="session")
async def eth(deployer) -> Contract:
    return await get_eth_contract(provider=deployer)


@pytest.fixture(scope="session")
def cairo_counter(deployer) -> Contract:
    """
    Return a cached version of the cairo_counter contract.
    """
    return get_contract("Counter", provider=deployer)


@pytest.fixture(scope="session")
def kakarot(deployer) -> Contract:
    """
    Return a cached deployer for the whole session.
    """
    return get_contract("kakarot", provider=deployer)


@pytest.fixture
def block_number():
    from kakarot_scripts.constants import WEB3

    async def _factory(block_number: Optional[Union[int, str]] = "latest"):
        if WEB3.is_connected():
            return WEB3.eth.get_block(block_number).number

        return (
            await RPC_CLIENT.get_block_with_tx_hashes(block_number=block_number)
        ).block_number

    return _factory


@pytest.fixture
def block_timestamp():
    from kakarot_scripts.constants import WEB3

    async def _factory(block_number: Optional[Union[int, str]] = "latest"):
        if WEB3.is_connected():
            return WEB3.eth.get_block(block_number).timestamp

        return (
            await RPC_CLIENT.get_block_with_tx_hashes(block_number=block_number)
        ).timestamp

    return _factory


@pytest.fixture
def block_hash():
    from kakarot_scripts.constants import WEB3

    async def _factory(block_number: Optional[Union[int, str]] = "latest"):
        if WEB3.is_connected():
            return WEB3.eth.get_block(block_number).hash

        return (
            await RPC_CLIENT.get_block_with_tx_hashes(block_number=block_number)
        ).block_hash

    return _factory


# Uniswap fixtures

TOTAL_SUPPLY = 10000 * 10**18


@pytest_asyncio.fixture(scope="function")
async def token_a(owner):
    return await deploy_kakarot(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def weth():
    return await deploy_kakarot("WETH", "WETH9")


@pytest_asyncio.fixture(scope="module")
async def factory(owner):
    return await deploy_kakarot("UniswapV2", "UniswapV2Factory", owner.address)


@pytest_asyncio.fixture(scope="module")
async def router(factory, weth):
    return await deploy_kakarot(
        "UniswapV2Router", "UniswapV2Router02", factory.address, weth.address
    )
