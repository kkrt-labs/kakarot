import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.helpers import generate_random_private_key


@pytest_asyncio.fixture(scope="module")
async def mock_externally_owned_account_class(starknet: Starknet):
    return await starknet.deprecated_declare(
        source="./tests/src/kakarot/accounts/eoa/mock_externally_owned_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="module")
async def mock_kakarot(
    starknet: Starknet,
    eth: StarknetContract,
    account_proxy_class: DeclaredClass,
    mock_externally_owned_account_class: DeclaredClass,
):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/accounts/eoa/mock_kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            eth.contract_address,
            account_proxy_class.class_hash,
            mock_externally_owned_account_class.class_hash,
        ],
    )


@pytest.fixture(scope="module")
async def private_key():
    return generate_random_private_key(seed=0)


@pytest_asyncio.fixture(scope="module")
async def mock_externally_owned_account(
    mock_kakarot: StarknetContract,
    private_key,
    mock_externally_owned_account_class: DeclaredClass,
):
    # mock_kakarot has no deployment_fee set up, so it transfers 0 ETH, but ERC20.transferFrom doesn't accept address 0 as a recipient.
    # We could update the ERC20 used in the tests, but because this check may be useful to prevent bugs elsewhere, it's better to
    # just put a random caller_address > 0 here
    contract_address = (
        await mock_kakarot.deploy_externally_owned_account(
            int(private_key.public_key.to_address(), 16)
        ).execute(caller_address=1)
    ).result.starknet_contract_address
    return StarknetContract(
        state=mock_kakarot.state,
        abi=mock_externally_owned_account_class.abi,
        contract_address=contract_address,
    )
