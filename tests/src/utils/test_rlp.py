import random
from pathlib import Path

import pytest
from rlp import decode, encode
from starkware.cairo.lang.cairo_constants import DEFAULT_PRIME
from starkware.cairo.lang.compiler.cairo_compile import compile_cairo

from tests.utils.cairo import run_program_entrypoint


@pytest.fixture(scope="module")
def program():
    path = Path("tests/src/utils/test_rlp.cairo")
    return compile_cairo(path.read_text(), cairo_path=["src"], prime=DEFAULT_PRIME)


class TestRLP:
    class TestDecode:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_decode_reference_implementation(
            self, program, payload_len
        ):
            random.seed(0)
            data = [random.randbytes(payload_len - 1)]
            encoded_data = encode(data)
            expected_result = decode(encoded_data)
            output = run_program_entrypoint(
                program=program,
                entrypoint="test__decode",
                program_input={"data": list(encoded_data), "is_list": 1},
            )

            output = run_program_entrypoint(
                program=program,
                entrypoint="test__decode",
                program_input={"data": output, "is_list": 0},
            )

            assert expected_result == [bytes(output)]
