import random
from functools import partial

import pytest
from rlp import decode, encode


@pytest.fixture(scope="module")
def program(cairo_compile):
    return cairo_compile("tests/src/utils/test_rlp.cairo")


@pytest.fixture()
def program_run(program, cairo_run):
    return partial(cairo_run, program=program)


class TestRLP:
    class TestDecode:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_decode_reference_implementation(
            self, program_run, payload_len
        ):
            random.seed(0)
            data = [random.randbytes(payload_len - 1)]
            encoded_data = encode(data)
            expected_result = decode(encoded_data)
            output = program_run(
                entrypoint="test__decode",
                program_input={"data": list(encoded_data), "is_list": 1},
            )

            output = program_run(
                entrypoint="test__decode",
                program_input={"data": output, "is_list": 0},
            )

            assert expected_result == [bytes(output)]
