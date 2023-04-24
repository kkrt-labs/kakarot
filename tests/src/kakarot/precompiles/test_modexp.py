import math
import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def modexp(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/src/kakarot/precompiles/test_modexp.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.MOD_EXP
class TestModExp:
    async def test_modexp(self, modexp):

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

        cairo_modexp = await modexp.test__modexp_impl(bytes_array).call()
        cairo_result = cairo_modexp.result[0]
        gas_cost = cairo_modexp.result[1]
        assert expected_result == cairo_result
        assert 1360 == gas_cost
