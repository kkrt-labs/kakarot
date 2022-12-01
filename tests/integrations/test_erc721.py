from typing import Callable

import pytest

from tests.utils.utils import hex_string_to_bytes_array


@pytest.mark.asyncio
@pytest.mark.SolmateERC721
class TestERC721:
    class TestDeploy:
        async def test_should_set_bytecode_name_and_symbol(
            self,
            deploy_solidity_contract: Callable,
        ):
            erc_721 = await deploy_solidity_contract(
                "ERC721", "Kakarot NFT", "KKNFT", caller_address=1
            )
            stored_bytecode = (
                await erc_721.contract_account.bytecode().call()
            ).result.bytecode
            contract_bytecode = hex_string_to_bytes_array(erc_721.bytecode.hex())
            deployed_bytecode = contract_bytecode[contract_bytecode.index(0xFE) + 1 :]
            assert stored_bytecode == deployed_bytecode
            name = await erc_721.name()
            assert name == "Kakarot NFT"
            symbol = await erc_721.symbol()
            assert symbol == "KKNFT"
