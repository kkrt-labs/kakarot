import random

import pytest


@pytest.mark.parametrize(
    "test_case,data,expected",
    [
        (
            "test__bytes4_array_to_bytes",
            [
                0x68656C6C,
                0x6F20776F,
                0x726C6400,
            ],
            [
                0x68,
                0x65,
                0x6C,
                0x6C,
                0x6F,
                0x20,
                0x77,
                0x6F,
                0x72,
                0x6C,
                0x64,
                0x00,
            ],
        ),
        (
            "test__bytes_to_bytes4_array",
            [
                0x68,
                0x65,
                0x6C,
                0x6C,
                0x6F,
                0x20,
                0x77,
                0x6F,
                0x72,
                0x6C,
                0x64,
                0x00,
            ],
            [
                0x68656C6C,
                0x6F20776F,
                0x726C6400,
            ],
        ),
        ("test__bytes_i_to_uint256", [], []),
    ],
)
def test_utils(cairo_run, test_case, data, expected):
    cairo_run(test_case, data=data, expected=expected)


def test_should_return_bytes_used_in_128_word(cairo_run):
    random.seed(0)
    # Generate 50 random 128-bit words
    for _ in range(20):
        word = random.randint(0, 2**128 - 1)
        bytes_length = (word.bit_length() + 7) // 8
        output = cairo_run(
            "test__bytes_used_128",
            word=word,
        )
        assert bytes_length == output[0]
