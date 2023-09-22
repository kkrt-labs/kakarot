import pytest_asyncio

TOTAL_SUPPLY = 10000 * 10**18


@pytest_asyncio.fixture(scope="module")
async def token_a(
    deploy_solidity_contract,
    owner,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def token_b(
    deploy_solidity_contract,
    owner,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "ERC20",
        TOTAL_SUPPLY,
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
async def pair(
    deploy_solidity_contract,
    token_a,
    token_b,
    factory,
    owner,
):
    # TODO: the fixture should use factory.createPair but this currently fails
    # TODO: with OUT_OF_RESOURCES so we do it via an EOA for the sake of running
    # TODO: the UniswapV2Pair tests
    _pair = await deploy_solidity_contract(
        "UniswapV2",
        "UniswapV2Pair",
        caller_eoa=owner.starknet_contract,
    )
    token_0, token_1 = (
        (token_a, token_b) if token_a.address < token_a.address else (token_b, token_a)
    )
    await _pair.initialize(
        _token0=token_0.address,
        _token1=token_1.address,
        caller_eoa=factory.contract_account,
    )
    return _pair, token_0, token_1
