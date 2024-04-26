import pytest_asyncio

TOTAL_SUPPLY = 10000 * 10**18


@pytest_asyncio.fixture(scope="session")
async def token_a(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def weth(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "WETH",
        "WETH9",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def factory(
    deploy_solidity_contract,
    owner,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "UniswapV2Factory",
        owner.address,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def router(
    deploy_solidity_contract,
    owner,
    factory,
    weth,
):
    return await deploy_solidity_contract(
        "UniswapV2Router",
        "UniswapV2Router02",
        factory.address,
        weth.address,
        caller_eoa=owner.starknet_contract,
    )
