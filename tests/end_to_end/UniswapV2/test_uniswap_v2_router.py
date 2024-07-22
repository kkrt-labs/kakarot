import pytest

from kakarot_scripts.utils.kakarot import deploy


@pytest.mark.asyncio(scope="session")
@pytest.mark.UniswapV2Router
class TestUniswapV2Router:
    class TestDeploy:
        async def test_should_set_constants(self, router, weth, factory):
            assert await router.WETH() == weth.address
            assert await router.factory() == factory.address

    class TestAddLiquidity:
        async def test_should_add_liquidity(self, router, token_a, owner):
            token_b = await deploy(
                "UniswapV2",
                "ERC20",
                int(10000e18),
                caller_eoa=owner.starknet_contract,
            )

            amount_A_desired = (
                1000 * await token_a.decimals()
            )  # This needs to match the token's decimals
            amount_B_desired = (
                500 * await token_b.decimals()
            )  # Assuming WETH has 18 decimals

            await token_a.mint(
                owner.address, amount_A_desired, caller_eoa=owner.starknet_contract
            )
            await token_b.mint(
                owner.address, amount_B_desired, caller_eoa=owner.starknet_contract
            )

            await token_a.approve(
                router.address, amount_A_desired * 2, caller_eoa=owner.starknet_contract
            )
            await token_b.approve(
                router.address, amount_B_desired * 2, caller_eoa=owner.starknet_contract
            )

            deadline = 99999999999
            to_address = owner.address
            success = (
                await router.addLiquidity(
                    token_a.address,
                    token_b.address,
                    amount_A_desired,
                    amount_B_desired,
                    0,
                    0,
                    to_address,
                    deadline,
                    caller_eoa=owner.starknet_contract,
                )
            )["success"]
            assert success == 1
