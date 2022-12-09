import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def eth(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/fixtures/ERC20.cairo",
        constructor_calldata=[2] * 6,
        # Uint256(2, 2) tokens to 2
    )


@pytest_asyncio.fixture(scope="session")
async def contract_account_class(starknet: Starknet):
    return await starknet.declare(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="package")
async def kakarot(
    starknet: Starknet, eth: StarknetContract, contract_account_class: DeclaredClass
) -> StarknetContract:
    kakarot_contract = await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[],
    )

    await kakarot_contract.init(
        1, eth.contract_address, contract_account_class.class_hash  # owner
    ).execute(caller_address=1)

    return kakarot_contract
