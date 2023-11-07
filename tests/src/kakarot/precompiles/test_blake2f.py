import random
from typing import cast

import pytest
import pytest_asyncio
from eth._utils.blake2.compression import TMessageBlock, blake2b_compress
from starkware.starknet.testing.starknet import Starknet

from tests.utils.helpers import pack_64_bits_little


@pytest_asyncio.fixture(scope="module")
async def blake2f(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/precompiles/test_blake2f.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
@pytest.mark.BLAKE2F
class TestBlake2f:
    async def test_should_fail_when_input_len_is_not_213(self, blake2f):
        (output,) = (
            await blake2f.test_should_fail_when_input_is_not_213().call()
        ).result
        assert bytes(output).decode() == "Precompile: wrong input_len"

    async def test_should_fail_when_flag_is_not_0_or_1(self, blake2f):
        (output,) = (
            await blake2f.test_should_fail_when_flag_is_not_0_or_1().call()
        ).result
        assert bytes(output).decode() == "Precompile: flag error"

    @pytest.mark.parametrize("f", [0, 1])
    @pytest.mark.parametrize("seed", [0, 1, 2, 3, 4])
    async def test_should_return_blake2f_compression(self, blake2f, f, seed):
        random.seed(seed)

        # Given
        rounds = random.randint(1, 20)
        h = [random.getrandbits(8) for _ in range(64)]
        m = [random.getrandbits(8) for _ in range(128)]
        t0 = random.getrandbits(64)
        t1 = random.getrandbits(64)
        h_starting_state = [
            pack_64_bits_little(h[i * 8 : (i + 1) * 8]) for i in range(8)
        ]

        # When
        got = await blake2f.test_should_return_blake2f_compression(
            rounds, h, m, t0, t1, f
        ).call()

        # Then
        compress = blake2b_compress(
            rounds, cast(TMessageBlock, h_starting_state), m, (t0, t1), bool(f)
        )
        expected = [int(x) for x in compress]
        assert got.result.output == expected
