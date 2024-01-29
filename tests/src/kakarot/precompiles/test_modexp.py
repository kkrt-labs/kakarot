import math
import random

import pytest


@pytest.mark.MOD_EXP
class TestModExp:
    def test_modexp(self, cairo_run):
        random.seed(0)
        b = 3
        b_size = math.ceil(math.log(b, 256))
        b_size_bytes = b_size.to_bytes(32, "big")
        b_bytes = b.to_bytes(b_size, "big")

        e = 2**256 - 2**32 - 978
        e_size = math.ceil(math.log(e, 256))
        e_size_bytes = e_size.to_bytes(32, "big")
        e_bytes = e.to_bytes(e_size, "big")

        m = 2**256 - 2**32 - 977
        m_size = math.ceil(math.log(m, 256))
        m_size_bytes = m_size.to_bytes(32, "big")
        m_bytes = m.to_bytes(m_size, "big")

        bytes_array = list(
            b_size_bytes + e_size_bytes + m_size_bytes + b_bytes + e_bytes + m_bytes
        )
        expected_result = pow(b, e, m)

        cairo_result, gas_cost = cairo_run("test__modexp_impl", data=bytes_array)
        assert expected_result == cairo_result
        assert 1360 == gas_cost
