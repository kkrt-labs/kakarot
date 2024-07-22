import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy

TOTAL_SUPPLY = 10000 * 10**18


@pytest_asyncio.fixture(scope="function")
async def token_a(owner):
    return await deploy(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def weth(owner):
    return await deploy(
        "WETH",
        "WETH9",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def factory(owner):
    return await deploy(
        "UniswapV2",
        "UniswapV2Factory",
        owner.address,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def router(owner, factory, weth):
    return await deploy(
        "UniswapV2Router",
        "UniswapV2Router02",
        factory.address,
        weth.address,
        caller_eoa=owner.starknet_contract,
    )
