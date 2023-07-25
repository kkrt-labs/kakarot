import pytest

from tests.utils.errors import kakarot_error

TEST_ADDRESSES = [
    "0x1000000000000000000000000000000000000000",
    "0x2000000000000000000000000000000000000000",
]


@pytest.mark.asyncio
@pytest.mark.UniswapV2Factory
@pytest.mark.usefixtures("starknet_snapshot")
class TestUniswapV2Factory:
    class TestDeploy:
        async def test_should_set_constants(self, factory, uniswap_factory_deployer):
            owner = uniswap_factory_deployer
            assert await factory.feeTo() == f"0x{0:040x}"
            assert await factory.feeToSetter() == owner.address
            assert await factory.allPairsLength() == 0

    class TestCreatePair:
        @pytest.mark.parametrize("tokens", [TEST_ADDRESSES, TEST_ADDRESSES[::-1]])
        async def test_should_create_pair_only_once(
            self,
            factory,
            get_solidity_contract,
            get_starknet_address,
            owner,
            tokens,
        ):
            pair_evm_address = await factory.createPair(
                *tokens, caller_address=owner.starknet_address
            )
            token_0, token_1 = sorted(tokens)
            assert factory.events.PairCreated == [
                {
                    "token0": token_0,
                    "token1": token_1,
                    "pair": pair_evm_address,
                    "": 1,
                }
            ]

            with kakarot_error("UniswapV2: PAIR_EXISTS"):
                await factory.createPair(
                    *tokens,
                    caller_address=owner.starknet_address,
                )

            with kakarot_error("UniswapV2: PAIR_EXISTS"):
                await factory.createPair(
                    *tokens[::-1],
                    caller_address=owner.starknet_address,
                )

            assert await factory.getPair(*tokens) == pair_evm_address
            assert await factory.getPair(*tokens[::-1]) == pair_evm_address
            assert await factory.allPairs(0) == pair_evm_address
            assert await factory.allPairsLength() == 1

            pair_starknet_address = get_starknet_address(int(pair_evm_address, 16))
            pair = get_solidity_contract(
                "UniswapV2",
                "UniswapV2Pair",
                pair_starknet_address,
                pair_evm_address,
                None,
            )
            assert await pair.factory() == factory.evm_contract_address
            assert await pair.token0() == token_0
            assert await pair.token1() == token_1

        @pytest.mark.skip("Skipped because gas metering is inaccurate in kakarot")
        async def test_should_use_correct_gas(self, factory, owner):
            await factory.createPair(
                *TEST_ADDRESSES, caller_address=owner.starknet_address
            )
            assert factory.tx.result.gas_used == 2512920

    class TestSetFeeTo:
        async def test_should_revert_when_caller_is_not_owner(self, factory, other):
            with kakarot_error("UniswapV2: FORBIDDEN"):
                await factory.setFeeTo(
                    other.address, caller_address=other.starknet_address
                )

        async def test_should_set_fee_to_owner(self, factory, uniswap_factory_deployer):
            owner = uniswap_factory_deployer
            await factory.setFeeTo(owner.address, caller_address=owner.starknet_address)
            assert await factory.feeTo() == owner.address

    class TestSetFeeToSetter:
        async def test_should_revert_when_caller_is_not_owner(self, factory, other):
            with kakarot_error("UniswapV2: FORBIDDEN"):
                await factory.setFeeToSetter(
                    other.address, caller_address=other.starknet_address
                )

        async def test_should_set_fee_setter_to_other_and_transfer_permission(
            self, factory, uniswap_factory_deployer, other
        ):
            owner = uniswap_factory_deployer
            await factory.setFeeToSetter(
                other.address, caller_address=owner.starknet_address
            )
            assert await factory.feeToSetter() == other.address

            with kakarot_error("UniswapV2: FORBIDDEN"):
                await factory.setFeeToSetter(
                    owner.address, caller_address=owner.starknet_address
                )
