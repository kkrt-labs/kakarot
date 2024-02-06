import pytest
from hypothesis import given, settings
from hypothesis import strategies as st


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


@given(word=st.integers(min_value=0, max_value=2**128 - 1))
@settings(max_examples=20, deadline=None)
def test_should_return_bytes_used_in_128_word(cairo_run, word):
    bytes_length = (word.bit_length() + 7) // 8
    output = cairo_run(
        "test__bytes_used_128",
        word=word,
    )
    assert bytes_length == output[0]


@pytest.mark.parametrize(
    "bytes,expected",
    [
        (b"", [1, 0, 0]),  # An empty address
        (
            b"\x01" * 20,
            [1, 1, 0x0101010101010101010101010101010101010101],
        ),  # An address of 20 bytes
        (b"\x01" * 40, [0, 0, 0]),  # and invalid address
    ],
)
def test_should_parse_address_from_bytes(cairo_run, bytes, expected):
    result = cairo_run("test__try_parse_destination_from_bytes", bytes=list(bytes))
    assert result == expected
