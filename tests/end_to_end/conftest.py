import logging
from collections import namedtuple
from functools import partial
from typing import List, Optional, Union

import pytest
import pytest_asyncio
from eth_utils.address import to_checksum_address
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account

from kakarot_scripts.utils.starknet import wait_for_transaction
from tests.utils.helpers import generate_random_private_key

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

Wallet = namedtuple("Wallet", ["address", "private_key", "starknet_contract"])


@pytest.fixture(scope="session")
def zero_fee():
    """
    Return max fee hardcoded to 0 ETH. This allows to
    set the allowed number of execute steps to whatever is passed
    when launching Katana.
    """
    return int(0)


@pytest.fixture(scope="session")
def max_fee():
    """
    Return max fee hardcoded to 1 ETH to make sure tx passes
    it is not used per se in the test.
    """
    return int(5e17)


@pytest.fixture(scope="session", autouse=True)
def starknet():
    """
    End-to-end tests assume that there is already a "Starknet" network running
    with kakarot deployed.
    We return the RPC_CLIENT in a fixture to avoid importing in the tests the kakarot_scripts.utils
    but gather instead in fixtures all the utils. Using only fixtures in the tests will make
    it easier to later on change the backend without rewriting the tests.

    Since this `starknet` fixture is run before all the others, setting the STARKNET_NETWORK
    environment variable here would effectively change the target network of the test suite.
    """
    from kakarot_scripts.constants import RPC_CLIENT

    return RPC_CLIENT


@pytest_asyncio.fixture(scope="session")
async def addresses(max_fee) -> List[Wallet]:
    """
    Return a list of addresses to be used in tests.
    Addresses are returned as named tuples with:
    - address: the EVM address as int.
    - private_key: the PrivateKey of this address.
    - starknet_contract: the deployed Starknet contract handling this EOA.
    """
    from kakarot_scripts.utils.kakarot import get_eoa

    wallets = []
    for i in range(5):
        private_key = generate_random_private_key(seed=i)
        wallets.append(
            Wallet(
                address=private_key.public_key.to_checksum_address(),
                private_key=private_key,
                # deploying an account with enough ETH to pass ~10 tx
                starknet_contract=await get_eoa(
                    private_key, amount=100 * max_fee / 1e18
                ),
            )
        )
    return wallets


@pytest_asyncio.fixture(scope="session")
async def owner(addresses, eth_balance_of):
    """
    Return the main caller of all tests.
    Because owner is making most of the call, we make sure that at the beginning
    of the test session that they have a lot of ETH.
    """
    account = addresses[0]
    current_balance = await eth_balance_of(account.address)
    if current_balance / 1e18 < 10:
        from kakarot_scripts.utils.starknet import fund_address

        await fund_address(account.starknet_contract.address, 10)
    return addresses[0]


@pytest_asyncio.fixture(scope="session")
def other(addresses):
    return addresses[1]


@pytest_asyncio.fixture(scope="session")
def others(addresses):
    return addresses[2:]


@pytest_asyncio.fixture(scope="session")
async def deployer() -> Account:
    """
    Return a cached version of the deployer contract.
    """

    from kakarot_scripts.utils.starknet import get_starknet_account

    return await get_starknet_account()


@pytest_asyncio.fixture(scope="session")
async def eth(deployer) -> Contract:
    """
    Return a cached version of the eth contract.
    """

    from kakarot_scripts.utils.starknet import get_eth_contract

    return await get_eth_contract(provider=deployer)


@pytest.fixture(scope="session")
def fund_starknet_address(deployer, eth):
    """
    Return a cached fund_starknet_address for the whole session.
    """

    from kakarot_scripts.utils.starknet import fund_address

    return partial(fund_address, funding_account=deployer, token_contract=eth)


@pytest.fixture(scope="session")
def kakarot(deployer) -> Contract:
    """
    Return a cached deployer for the whole session.
    """
    from kakarot_scripts.utils.starknet import get_contract

    return get_contract("kakarot", provider=deployer)


@pytest.fixture(scope="session")
def compute_starknet_address(kakarot: Contract):
    """
    Isolate the starknet-py logic and make the test agnostic of the backend.
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
    Isolate the starknet-py logic and make the test agnostic of the backend.
    """

    async def _factory(evm_address: Union[int, str]):
        if isinstance(evm_address, str):
            evm_address = int(evm_address, 16)
        tx = await kakarot.functions["deploy_externally_owned_account"].invoke_v1(
            evm_address, max_fee=max_fee
        )
        await wait_for_transaction(tx.hash)
        return tx

    return _factory


@pytest.fixture(scope="session")
def register_account(kakarot: Contract, max_fee: int):
    """
    Isolate the starknet-py logic and make the test agnostic of the backend.
    """

    async def _factory(evm_address: Union[int, str]):
        if isinstance(evm_address, str):
            evm_address = int(evm_address, 16)
        tx = await kakarot.functions["register_account"].invoke_v1(
            evm_address, max_fee=max_fee
        )
        await wait_for_transaction(tx.hash)
        return tx

    return _factory


@pytest.fixture(scope="session")
def get_contract(deployer):
    """
    Wrap script.utils.starknet.get_contract to make the test are agnostics of the utils.
    """
    from kakarot_scripts.utils.starknet import get_contract

    def _factory(contract_name, address=None, provider=deployer):
        return get_contract(
            contract_name=contract_name,
            address=address,
            provider=provider,
        )

    return _factory


@pytest.fixture(scope="session")
def eth_balance_of(eth: Contract, compute_starknet_address):
    """
    Get the balance of an address.
    Accept both EVM and Starknet address, int or hex str.
    """

    async def _factory(address: Union[int, str]):
        try:
            evm_address = to_checksum_address(address)
            address = await compute_starknet_address(evm_address)
        # trunk-ignore(ruff/E722)
        except:
            address = address if isinstance(address, int) else int(address, 16)

        return (await eth.functions["balanceOf"].call(address)).balance

    return _factory


@pytest.fixture(scope="session")
def deploy_solidity_contract(zero_fee: int):
    """
    Fixture to attach a modified web3.contract instance to an already deployed contract_account in kakarot.
    """

    from kakarot_scripts.utils.kakarot import deploy

    async def _factory(contract_app, contract_name, *args, **kwargs):
        """
        Create a web3.contract based on the basename of the target solidity file.
        """
        return await deploy(
            contract_app, contract_name, *args, **kwargs, max_fee=zero_fee
        )

    return _factory


@pytest.fixture(scope="session")
def get_solidity_contract():
    """
    Fixture to attach a modified web3.contract instance to an already deployed contract_account in kakarot.
    """

    from kakarot_scripts.utils.kakarot import get_contract

    def _factory(contract_app, contract_name, *args, **kwargs):
        """
        Create a web3.contract based on the basename of the target solidity file.
        """
        return get_contract(contract_app, contract_name, *args, **kwargs)

    return _factory


@pytest.fixture
def block_with_tx_hashes(starknet):
    """
    Not using starknet object because of
    https://github.com/software-mansion/starknet.py/issues/1174.
    """

    async def _factory(block_number: Optional[int] = None):
        return await starknet.get_block_with_tx_hashes(block_number=block_number)

    return _factory


@pytest.fixture
def is_account_deployed(starknet, compute_starknet_address):
    """
    Return True if the corresponding EVM account is already deployed, False otherwise.
    """

    from starknet_py.net.client_errors import ClientError

    async def _factory(evm_address: Union[str, int]):
        starknet_address = await compute_starknet_address(evm_address)
        try:
            await starknet.get_class_hash_at(starknet_address)
            return True
        except ClientError as e:
            if "Contract not found" in e.message:
                return False

    return _factory


@pytest.fixture
def eth_send_transaction(max_fee, owner):
    """
    Send a decoded transaction to Kakarot.
    """
    from kakarot_scripts.utils.kakarot import eth_send_transaction

    return partial(
        eth_send_transaction, max_fee=max_fee, caller_eoa=owner.starknet_contract
    )


@pytest.fixture
def eth_get_code():
    """
    Send a decoded transaction to Kakarot.
    """
    from kakarot_scripts.utils.kakarot import eth_get_code

    return eth_get_code


@pytest.fixture
def call():
    """
    Send a Starknet call.
    """
    from kakarot_scripts.utils.starknet import call

    return call


@pytest.fixture
def invoke():
    """
    Send a Starknet transaction.
    """
    from kakarot_scripts.utils.starknet import invoke

    return invoke
