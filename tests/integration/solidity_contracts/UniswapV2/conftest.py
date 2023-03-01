from typing import Callable

import pytest_asyncio

TOTAL_SUPPLY = 10000 * 10**18


@pytest_asyncio.fixture(scope="module")
async def token_a(
    deploy_solidity_contract: Callable,
    owner,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_address=owner.starknet_address,
    )


@pytest_asyncio.fixture(scope="module")
async def token_b(
    deploy_solidity_contract: Callable,
    others,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_address=others[0].starknet_address,
    )


@pytest_asyncio.fixture(scope="module")
async def factory(
    deploy_solidity_contract: Callable,
    others,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "UniswapV2Factory",
        others[1].address,
        caller_address=others[1].starknet_address,
    )


@pytest_asyncio.fixture(scope="module")
async def pair(
    deploy_solidity_contract: Callable,
    token_a,
    token_b,
    factory,
):
    # TODO: the fixture should use factory.createPair but this currently fails
    # TODO: with OUT_OF_RESOURCES so we do it "manually" for the sake of running
    # TODO: the UniswapV2Pair tests
    _pair = await deploy_solidity_contract(
        "UniswapV2",
        "UniswapV2Pair",
        caller_address=factory.contract_account.contract_address,
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
