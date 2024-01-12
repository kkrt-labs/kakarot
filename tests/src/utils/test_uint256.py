import pytest

from tests.utils.uint256 import int_to_uint256


class TestUint256:
    class TestUint256ToUint160:
        @pytest.mark.parametrize("n", [0, 2**128, 2**160 - 1, 2**160, 2**256])
        def test_should_cast_value(self, cairo_run, n):
            cairo_run(
                "test__uint256_to_uint160", x=int_to_uint256(n), expected=n % 2**160
            )
