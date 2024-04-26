import pytest


@pytest.mark.asyncio(scope="session")
@pytest.mark.UniswapV2Router
class TestUniswapV2Router:
    class TestDeploy:
        async def test_should_set_constants(self, router, weth, factory):
            assert await router.WETH() == weth.address
            print("WETH Address", weth.address)
            assert await router.factory() == factory.address

    class TestAddLiquidity:
        async def test_should_add_liquidity(self, router, token_b, token_a, owner):
            amount_A_desired = (
                1000 * await token_a.decimals()
            )  # This needs to match the token's decimals
            amount_B_desired = (
                500 * await token_b.decimals()
            )  # Assuming WETH has 18 decimals

            amount_A_min = 0
            amount_B_min = 0

            deadline = 99999999999

            to_address = owner.address

            print(token_a.address)
            print(token_b.address)
            print("WETH Address", await router.WETH())

            await token_a.mint(
                owner.address, amount_A_desired, caller_eoa=owner.starknet_contract
            )
            await token_b.mint(
                owner.address, amount_B_desired, caller_eoa=owner.starknet_contract
            )

            balance_a = await token_a.balanceOf(owner.address)
            balance_b = await token_b.balanceOf(owner.address)

            print("balance_a: ", balance_a)
            print("balance_b: ", balance_b)

            await token_a.approve(
                router.address, amount_A_desired * 2, caller_eoa=owner.starknet_contract
            )
            await token_b.approve(
                router.address, amount_B_desired * 2, caller_eoa=owner.starknet_contract
            )

            allowance_a = await token_a.allowance(owner.address, router.address)
            allowance_b = await token_b.allowance(owner.address, router.address)

            print("allowance_a: ", allowance_a)
            print("allowance_b: ", allowance_b)

            try:
                success = (
                    await router.addLiquidity(
                        token_a.address,
                        token_b.address,
                        amount_A_desired,
                        amount_B_desired,
                        amount_A_min,
                        amount_B_min,
                        to_address,
                        deadline,
                        caller_eoa=owner.starknet_contract,
                    )
                )["success"]
                assert success == 1
            except Exception as e:
                print(f"Transaction failed: {str(e)}")
                raise
