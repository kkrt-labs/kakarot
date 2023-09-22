import pytest

TEST_ADDRESSES = [
    "0x1000000000000000000000000000000000000000",
    "0x2000000000000000000000000000000000000000",
]


@pytest.mark.asyncio
@pytest.mark.UniswapV2Factory
class TestUniswapV2Factory:
    class TestDeploy:
        async def test_should_set_constants(self, factory, owner):
            assert await factory.feeTo() == f"0x{0:040x}"
            assert await factory.feeToSetter() == owner.address
            assert await factory.allPairsLength() == 0

    class TestCreatePair:
        @pytest.mark.parametrize("tokens", [TEST_ADDRESSES, TEST_ADDRESSES[::-1]])
        async def test_should_create_pair_only_once(
            self,
            factory,
            get_solidity_contract,
            owner,
            tokens,
        ):
            receipt = await factory.createPair(*tokens, caller_eoa=owner, max_fee=0)
            # if no events, then the pair already exists
            # TODO: update when Katana passes the revert reason
            if not receipt.events:
                return
            token_0, token_1 = sorted(tokens)
            pair_evm_address = await factory.getPair(*tokens)
            assert factory.events.parse_starknet_events(receipt.events)[
                "PairCreated"
            ] == [
                {
                    "token0": token_0,
                    "token1": token_1,
                    "pair": pair_evm_address,
                    "": 1,
                }
            ]

            receipt = await factory.createPair(*tokens, caller_eoa=owner, max_fee=0)
            assert not receipt.events

            receipt = await factory.createPair(
                *tokens[::-1], caller_eoa=owner, max_fee=0
            )
            assert not receipt.events

            assert await factory.getPair(*tokens) == pair_evm_address
            assert await factory.getPair(*tokens[::-1]) == pair_evm_address
            assert await factory.allPairs(0) == pair_evm_address
            assert await factory.allPairsLength() == 1

            pair = get_solidity_contract(
                "UniswapV2",
                "UniswapV2Pair",
                address=pair_evm_address,
            )
            assert await pair.factory() == factory.address
            assert await pair.token0() == token_0
            assert await pair.token1() == token_1

        @pytest.mark.skip("Skipped because gas metering is inaccurate in kakarot")
        async def test_should_use_correct_gas(self, factory, owner):
            await factory.createPair(*TEST_ADDRESSES, caller_eoa=owner, max_fee=0)
            assert factory.tx.result.gas_used == 2512920

    class TestSetFeeTo:
        async def test_should_revert_when_caller_is_not_owner(self, factory, other):
            await factory.setFeeTo(other.address, caller_eoa=other)
            assert await factory.feeTo() != other.address

        async def test_should_set_fee_to_owner(self, factory, owner):
            await factory.setFeeTo(owner.address, caller_eoa=owner, max_fee=0)
            assert await factory.feeTo() == owner.address

    class TestSetFeeToSetter:
        async def test_should_revert_when_caller_is_not_owner(self, factory, other):
            await factory.setFeeToSetter(other.address, caller_eoa=other)
            assert await factory.feeToSetter() != other.address

        async def test_should_set_fee_setter_to_other_and_transfer_permission(
            self, factory, owner, other
        ):
            await factory.setFeeToSetter(other.address, caller_eoa=owner)
            assert await factory.feeToSetter() == other.address

            await factory.setFeeToSetter(owner.address, caller_eoa=owner)
            assert await factory.feeToSetter() != owner.address
