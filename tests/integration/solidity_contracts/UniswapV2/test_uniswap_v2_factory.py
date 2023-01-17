import random
import re
from typing import Callable

import pytest
import pytest_asyncio
from eth_abi import encode_abi
from eth_utils import keccak, to_checksum_address

from tests.integration.helpers.helpers import get_create2_address
from tests.utils.errors import kakarot_error

# TODO: Fix these addresses with the original ones once
# TODO: https://github.com/sayajin-labs/kakarot/issues/439 is fixed
TEST_ADDRESSES = [
    to_checksum_address(f"{random.randint(0, 2**160):x}") for _ in range(2)
]


@pytest_asyncio.fixture(scope="module")
async def factory(
    deploy_solidity_contract: Callable,
    owner,
):
    return await deploy_solidity_contract(
        "UniswapV2",
        "UniswapV2Factory",
        owner.address,
        caller_address=owner.starknet_address,
    )


@pytest.fixture(scope="module")
async def other(others):
    return others[0]


@pytest.mark.asyncio
@pytest.mark.UniswapV2Factory
@pytest.mark.usefixtures("starknet_snapshot")
class TestUniswapV2Factory:
    class TestDeploy:
        async def test_should_set_constants(self, factory, owner):
            assert await factory.feeTo() == f"0x{0:040x}"
            assert await factory.feeToSetter() == owner.address
            assert await factory.allPairsLength() == 0

    class TestCreatePair:
        @pytest.mark.skip("Raises with StarknetErrorCode.OUT_OF_RESOURCES: 42")
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
            assert factory.events.PairCreated == [
                {
                    "token0": tokens[0],
                    "token1": tokens[1],
                    "pair": pair_evm_address,
                    "all_pairs_length": 1,
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

            salt = keccak(encode_abi(["address", "address"], sorted(tokens)))
            pair_starknet_address = await get_starknet_address(salt)
            pair = get_solidity_contract(
                "UniswapV2", "UniswapV2Pair", pair_starknet_address, pair_evm_address
            )
            assert await pair.factory() == factory.evm_contract_address
            assert await pair.token0() == tokens[0]
            assert await pair.token1() == tokens[1]

        @pytest.mark.skip("gas_usage is not yet returned by kakarot")
        async def test_should_use_correct_gas(self, factory, owner):
            # TODO: see https://github.com/sayajin-labs/kakarot/issues/428
            tx = await factory.createPair(
                *TEST_ADDRESSES, caller_address=owner.starknet_address
            )
            assert tx.gas_used == 2512920

    class TestSetFeeTo:
        async def test_should_revert_when_caller_is_not_owner(self, factory, other):
            with kakarot_error("UniswapV2: FORBIDDEN"):
                await factory.setFeeTo(
                    other.address, caller_address=other.starknet_address
                )

        async def test_should_set_fee_to_owner(self, factory, owner):
            await factory.setFeeTo(owner.address, caller_address=owner.starknet_address)
            assert await factory.feeTo() == owner.address

    class TestSetFeeToSetter:
        async def test_should_revert_when_caller_is_not_owner(self, factory, other):
            with kakarot_error("UniswapV2: FORBIDDEN"):
                await factory.setFeeToSetter(
                    other.address, caller_address=other.starknet_address
                )

        async def test_should_set_fee_setter_to_other_and_transfer_permission(
            self, factory, owner, other
        ):
            await factory.setFeeToSetter(
                other.address, caller_address=owner.starknet_address
            )
            assert await factory.feeToSetter() == other.address

            with kakarot_error("UniswapV2: FORBIDDEN"):
                await factory.setFeeToSetter(
                    owner.address, caller_address=owner.starknet_address
                )
