import pytest


@pytest.mark.EC_MUL
class TestEcMul:
    @pytest.mark.slow
    def test_ec_mul(self, cairo_run):
        cairo_run("test__ecmul_impl")
