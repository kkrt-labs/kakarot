import random
from typing import cast

import pytest
from eth._utils.blake2.compression import TMessageBlock, blake2b_compress

from tests.utils.helpers import pack_64_bits_little


@pytest.mark.BLAKE2F
class TestBlake2f:
    @pytest.mark.slow
    def test_should_fail_when_input_len_is_not_213(self, cairo_run):
        output = cairo_run("test_should_fail_when_input_is_not_213")
        assert bytes(output) == b"Precompile: wrong input_len"

    def test_should_fail_when_flag_is_not_0_or_1(self, cairo_run):
        output = cairo_run("test_should_fail_when_flag_is_not_0_or_1")
        assert bytes(output) == b"Precompile: flag error"

    @pytest.mark.slow
    @pytest.mark.parametrize("f", [0, 1])
    @pytest.mark.parametrize("seed", [0, 1, 2, 3, 4])
    def test_should_return_blake2f_compression(self, cairo_run, f, seed):
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
        output = cairo_run(
            "test_should_return_blake2f_compression",
            rounds=rounds,
            h=h,
            m=m,
            t0=t0,
            t1=t1,
            f=f,
        )

        # Then
        compress = blake2b_compress(
            rounds, cast(TMessageBlock, h_starting_state), m, (t0, t1), bool(f)
        )
        expected = [int(x) for x in compress]
        assert output == expected
