import pytest
import pytest_asyncio


@pytest_asyncio.fixture(scope="module")
async def univ3_position(deploy_contract, owner):
    return await deploy_contract(
        "UniswapV3",
        "UniswapV3NFTManager",
        associated_libraries=[("UniswapV3", "NFTDescriptor")],
        caller_eoa=owner.starknet_contract,
    )


@pytest.mark.asyncio(scope="session")
@pytest.mark.OpenZeppelinERC721
class TestUniswapV3Rendering:
    async def test_should_render_position(self, univ3_position):
        await univ3_position.tokenURI2(0)
        breakpoint()
