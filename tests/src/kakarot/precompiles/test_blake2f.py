import random

import pytest
import pytest_asyncio
from blake2b import compress
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error
from tests.utils.helpers import pack_64_bits_little


@pytest_asyncio.fixture(scope="module")
async def blake2f(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/src/kakarot/precompiles/test_blake2f.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.BLAKE2F
class TestBlake2f:
    async def test_should_fail_when_input_len_is_not_213(self, blake2f):
        with kakarot_error(
            "Kakarot: blake2f failed with incorrect input_len: 212 instead of 213"
        ):
            await blake2f.test_should_fail_when_input_is_not_213().call()

    async def test_should_fail_when_flag_is_not_0_or_1(self, blake2f):
        with kakarot_error(
            "Kakarot: blake2f failed with incorrect flag: 2 instead of 0 or 1"
        ):
            await blake2f.test_should_fail_when_flag_is_not_0_or_1().call()

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
        m_64 = [pack_64_bits_little(m[i * 8 : (i + 1) * 8]) for i in range(16)]
        c = compress(rounds, h_starting_state, m_64, [t0, t1], bool(f))
        expected = [int(x) for x in c]
        assert got.result.output == expected
