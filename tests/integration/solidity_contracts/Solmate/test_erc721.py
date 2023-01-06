import pytest


@pytest.mark.asyncio
@pytest.mark.SolmateERC721
class TestERC721:
    class TestDeploy:
        async def test_should_set_name_and_symbol(self, erc_721):
            name = await erc_721.name()
            assert name == "Kakarot NFT"
            symbol = await erc_721.symbol()
            assert symbol == "KKNFT"
