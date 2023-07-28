from typing import Callable

import pytest_asyncio

TOTAL_SUPPLY = 10000 * 10**18


@pytest_asyncio.fixture(scope="session")
async def token_a_deployer(addresses):
    return addresses[11]


@pytest_asyncio.fixture(scope="session")
async def token_b_deployer(addresses):
    return addresses[12]


@pytest_asyncio.fixture(scope="session")
async def uniswap_factory_deployer(addresses):
    return addresses[13]


@pytest_asyncio.fixture(scope="session")
async def uniswap_pair_deployer(addresses):
    return addresses[14]


@pytest_asyncio.fixture(scope="module")
async def token_a(
    deploy_solidity_contract: Callable,
    token_a_deployer,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=token_a_deployer,
    )


@pytest_asyncio.fixture(scope="module")
async def token_b(
    deploy_solidity_contract: Callable,
    token_b_deployer,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=token_b_deployer,
    )


@pytest_asyncio.fixture(scope="module")
async def factory(
    deploy_solidity_contract: Callable,
    uniswap_factory_deployer,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "UniswapV2Factory",
        uniswap_factory_deployer.address,
        caller_eoa=uniswap_factory_deployer,
    )


@pytest_asyncio.fixture(scope="module")
async def pair(
    deploy_solidity_contract: Callable,
    token_a,
    token_b,
    factory,
    uniswap_pair_deployer,
):
    # TODO: the fixture should use factory.createPair but this currently fails
    # TODO: with OUT_OF_RESOURCES so we do it via an EOA for the sake of running
    # TODO: the UniswapV2Pair tests
    _pair = await deploy_solidity_contract(
        "UniswapV2",
        "UniswapV2Pair",
        caller_eoa=uniswap_pair_deployer,
    )
    token_0, token_1 = (
        (token_a, token_b)
        if token_a.evm_contract_address < token_a.evm_contract_address
        else (token_b, token_a)
    )
    await _pair.initialize(
        _token0=token_0.evm_contract_address,
        _token1=token_1.evm_contract_address,
        caller_address=factory.contract_account.contract_address,
    )
    return _pair, token_0, token_1
