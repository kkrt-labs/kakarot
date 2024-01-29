import pytest


@pytest.mark.EC_MUL
class TestEcMul:
    def test_ec_mul(self, cairo_run):
        cairo_run("test__ecmul_impl")
