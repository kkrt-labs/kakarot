import pytest

from tests.utils.uint256 import int_to_uint256


@pytest.fixture(scope="module")
def program(cairo_compile):
    return cairo_compile("tests/src/utils/test_uint256.cairo")


class TestUint256:
    class TestUint256ToUint160:
        @pytest.mark.parametrize("n", [0, 2**128, 2**160 - 1, 2**160, 2**256])
        def test_should_cast_value(self, cairo_run, program, n):
            cairo_run(
                program=program,
                entrypoint="test__uint256_to_uint160",
                program_input={"x": int_to_uint256(n), "expected": n % 2**160},
            )
