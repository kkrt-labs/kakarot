import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="module")
async def univ3_position(owner):
    return await deploy(
        "UniswapV3",
        "UniswapV3NFTManager",
        caller_eoa=owner.starknet_contract,
    )


@pytest.mark.asyncio(scope="session")
@pytest.mark.xfail(reason="Rendering the SVG takes too many steps")
class TestUniswapV3Rendering:
    async def test_should_render_position(self, univ3_position):
        await univ3_position.tokenURIExternal(1)
