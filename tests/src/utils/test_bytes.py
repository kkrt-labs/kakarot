import pytest

from tests.utils.uint256 import int_to_uint256

PRIME = 0x800000000000011000000000000000000000000000000000000000000000001


@pytest.fixture(scope="module")
def program(cairo_compile):
    return cairo_compile("tests/src/utils/test_bytes.cairo")


class TestBytes:
    class TestFeltToAscii:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF])
        def test_should_return_ascii(self, cairo_run, program, n):
            output = cairo_run(
                program=program,
                entrypoint="test__felt_to_ascii",
                program_input={"n": n},
            )
            assert str(n) == bytes(output).decode()

    class TestFeltToBytesLittle:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        def test_should_return_bytes(self, cairo_run, program, n):
            output = cairo_run(
                program=program,
                entrypoint="test__felt_to_bytes_little",
                program_input={"n": n},
            )
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0"))[::-1] == res

    class TestFeltToBytes:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        def test_should_return_bytes(self, cairo_run, program, n):
            output = cairo_run(
                program=program,
                entrypoint="test__felt_to_bytes",
                program_input={"n": n},
            )
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0")) == res

    class TestFeltToBytes20:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        def test_should_return_bytes20(self, cairo_run, program, n):
            output = cairo_run(
                program=program,
                entrypoint="test__felt_to_bytes20",
                program_input={"n": n},
            )
            assert f"{n:064x}"[-40:] == bytes(output).hex()

    class TestUint256ToBytesLittle:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        def test_should_return_bytes(self, cairo_run, program, n):
            output = cairo_run(
                program=program,
                entrypoint="test__uint256_to_bytes_little",
                program_input={"n": int_to_uint256(n)},
            )
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0"))[::-1] == res

    class TestUint256ToBytes:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        def test_should_return_bytes(self, cairo_run, program, n):
            output = cairo_run(
                program=program,
                entrypoint="test__uint256_to_bytes",
                program_input={"n": int_to_uint256(n)},
            )
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0")) == res

    class TestUint256ToBytes32:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        def test_should_return_bytes(self, cairo_run, program, n):
            output = cairo_run(
                program=program,
                entrypoint="test__uint256_to_bytes32",
                program_input={"n": int_to_uint256(n)},
            )
            assert bytes.fromhex(f"{n:064x}") == bytes(output)

    class TestBytesToBytes8LittleEndian:
        @pytest.mark.parametrize("bytes_len", list(range(20)))
        def test_should_return_bytes8(self, cairo_run, program, bytes_len):
            bytes_array = list(range(bytes_len))
            bytes8_little_endian = [
                int(bytes(bytes_array[i : i + 8][::-1]).hex(), 16)
                for i in range(0, len(bytes_array), 8)
            ]
            output = cairo_run(
                program=program,
                entrypoint="test__bytes_to_bytes8_little_endian",
                program_input={"bytes": list(range(bytes_len))},
            )
            assert bytes8_little_endian == output
