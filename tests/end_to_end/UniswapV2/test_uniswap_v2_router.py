import pytest


@pytest.mark.asyncio(scope="session")
class TestUniswapV2Router:
    class TestDeploy:
        async def test_should_set_constants(self, deploy_solidity_contract):
            from eth_keys import keys

            from kakarot_scripts.utils.kakarot import get_eoa

            return await deploy_solidity_contract(
                "UniswapV2Router",
                "UniswapV2Router02",
                "0x0000000000000000000000000000000000000000",
                "0x0000000000000000000000000000000000000000",
                caller_eoa=await get_eoa(
                    keys.PrivateKey(
                        bytes.fromhex(
                            "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
                        )
                    ),
                    0,
                ),
            )
