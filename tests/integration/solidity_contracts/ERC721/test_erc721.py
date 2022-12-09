from typing import Callable

import pytest

from tests.integration.helpers.helpers import hex_string_to_bytes_array


@pytest.mark.asyncio
@pytest.mark.SolmateERC721
class TestERC721:
    class TestDeploy:
        async def test_should_set_name_and_symbol(
            self,
            deploy_solidity_contract: Callable,
        ):
            erc_721 = await deploy_solidity_contract(
                "ERC721", "Kakarot NFT", "KKNFT", caller_address=1
            )
            name = await erc_721.name()
            assert name == "Kakarot NFT"
            symbol = await erc_721.symbol()
            assert symbol == "KKNFT"
