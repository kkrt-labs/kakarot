from math import ceil

import pytest
from ethereum.cancun.vm.runtime import get_valid_jump_destinations
from hypothesis import given, settings
from hypothesis import strategies as st

from kakarot_scripts.utils.kakarot import get_contract


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
    ],
)
def test_utils(cairo_run, test_case, data, expected):
    cairo_run(test_case, data=data, expected=expected)


@given(word=st.integers(min_value=0, max_value=2**256 - 1))
@settings(max_examples=20, deadline=None)
def test_bytes_to_uint256(cairo_run, word):
    output = cairo_run(
        "test__bytes_to_uint256",
        word=int.to_bytes(word, ceil(word.bit_length() / 8), byteorder="big"),
    )
    assert int(output, 16) == word


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
        (b"", [0, 0]),  # An empty field
        (
            b"\x01" * 20,
            [1, 0x0101010101010101010101010101010101010101],
        ),  # An address of 20 bytes
        (b"\x01" * 40, [0, 0]),  # and invalid address
    ],
)
def test_should_parse_destination_from_bytes(cairo_run, bytes, expected):
    result = cairo_run("test__try_parse_destination_from_bytes", bytes=list(bytes))
    assert result == expected


@pytest.mark.parametrize(
    "data, expected",
    [
        (b"", []),  # An empty field
        (
            bytes.fromhex(
                "0800000000000000000000000000000000000000000000000000000000000000"
            ),
            [0x800000000000000000000000000000000000000000000000000000000000000],
        ),  # 251-bit word
        # two 128-bit words
        (
            bytes.fromhex("8000".zfill(64) + "7000".zfill(64)),
            [0x8000, 0x7000],
        ),
    ],
)
def test_should_load_256_bits_array(cairo_run, data, expected):
    result_len, result = cairo_run("test__load_256_bits_array", data=data)
    assert result == expected
    assert result_len == len(expected)


@pytest.mark.parametrize(
    "data, expected",
    [
        ([0xAB, 0xCD, 0xEF, 0x01], 0xABCDEF01),
        ([0x00, 0x00, 0x05, 0x67], 0x567),
    ],
)
def test_should_convert_bytes4_to_felt(cairo_run, data, expected):
    output = cairo_run("test__bytes4_to_felt", data=data)
    assert output == expected


@pytest.mark.parametrize(
    "data, expected",
    [
        ([0x8000, 0x7000], bytes.fromhex(f"{0x8000:064x}" + f"{0x7000:064x}")),
        ([0x8000], bytes.fromhex(f"{0x8000:064x}")),
        (
            [0x8000, 0x7000, 0x6000],
            bytes.fromhex(f"{0x8000:064x}" + f"{0x7000:064x}" + f"{0x6000:064x}"),
        ),
    ],
)
def test_should_unpack_felt_array_to_bytes32_array(cairo_run, data, expected):
    result = cairo_run("test__felt_array_to_bytes32_array", data=data)
    assert bytes(result) == expected


@pytest.mark.parametrize(
    "data",
    [
        ([2**248 - 1] * 10),
        ([2**248 - 1, 2**128]),
        [2**2],
        [0],
    ],
)
def test_should_unpack_felt_array_to_bytes31_array(cairo_run, data):
    result = cairo_run("test__felt_array_to_bytes31_array", data=data)
    expected = b"".join(word.to_bytes(31, "big") for word in data)
    breakpoint()
    assert bytes(result) == expected


class TestInitializeJumpdests:
    def test_should_return_same_as_execution_specs(self, cairo_run):
        bytecode = get_contract("PlainOpcodes", "Counter").bytecode_runtime
        output = cairo_run("test__initialize_jumpdests", bytecode=bytecode)
        assert set(output) == get_valid_jump_destinations(bytecode)
