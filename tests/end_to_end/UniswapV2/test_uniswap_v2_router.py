import pytest


@pytest.mark.asyncio(scope="session")
@pytest.mark.UniswapV2Router
class TestUniswapV2Router:        
    class TestDeploy:
        async def test_should_set_constants(self, router, token_WETH, factory):
            assert await router.WETH() == token_WETH.address
            assert await router.factory() == factory.address

    class TestAddLiquidity:
        async def test_should_add_liquidity(self, router, token_b, token_a, owner):
            # Set the desired amounts of token_WETH and token_a to be added to the pool
            amount_A_desired = 1000 * 10**18  # This needs to match the token's decimals
            amount_B_desired = 500 * 10**18   # Assuming WETH has 18 decimals

            amount_A_min = 0
            amount_B_min = 0

            deadline = 99999999999  # Use an appropriate value for testing

            to_address = owner.address

            await token_a.approve(router.address, amount_A_desired, caller_eoa=owner.starknet_contract)
            await token_b.approve(router.address, amount_B_desired, caller_eoa=owner.starknet_contract)

            (amountA, amountB, liquidity) = (
                await router.addLiquidity(
                    token_a.address,
                    token_b.address,
                    amount_A_desired,
                    amount_B_desired,
                    amount_A_min,
                    amount_B_min,
                    to_address,
                    deadline,
                    caller_eoa=owner.starknet_contract
                )
            )["return_value"]

            # Check the returned liquidity tokens are greater than 0
            assert liquidity > 0

            # Additional assertions can check balances of tokens and pool state if necessary
