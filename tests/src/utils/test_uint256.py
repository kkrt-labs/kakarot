from pathlib import Path

import pytest
from starkware.cairo.lang.cairo_constants import DEFAULT_PRIME
from starkware.cairo.lang.compiler.cairo_compile import compile_cairo

from tests.utils.cairo import run_program_entrypoint
from tests.utils.uint256 import int_to_uint256


@pytest.fixture(scope="module")
def program():
    path = Path("tests/src/utils/test_uint256.cairo")
    return compile_cairo(path.read_text(), cairo_path=["src"], prime=DEFAULT_PRIME)


class TestUint256:
    class TestUint256ToUint160:
        @pytest.mark.parametrize("n", [0, 2**128, 2**160 - 1, 2**160, 2**256])
        def test_should_cast_value(self, program, n):
            run_program_entrypoint(
                program=program,
                entrypoint="test__uint256_to_uint160",
                program_input={"x": int_to_uint256(n), "expected": n % 2**160},
            )
