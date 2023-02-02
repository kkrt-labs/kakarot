import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet
import math
import random
from tests.utils.uint256 import uint256_to_int

@pytest_asyncio.fixture(scope="module")
async def modexp(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_modexp.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestModExp:
    async def test_modexp(self, modexp):
        
        # 2^256-1
        max_int = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        b = random.randint(0, max_int)
        b_size = math.ceil(math.log(b,256))
        b_size_bytes = b_size.to_bytes(32, "big")
        b_bytes = b.to_bytes(b_size, "big")

        e = random.randint(0, max_int)
        e_size = math.ceil(math.log(e,256))
        e_size_bytes = e_size.to_bytes(32, "big")
        e_bytes = e.to_bytes(e_size, "big")

        m = random.randint(0, max_int)
        m_size = math.ceil(math.log(m,256))
        m_size_bytes = m_size.to_bytes(32, "big")
        m_bytes = m.to_bytes(m_size, "big")

        bytes_array = list(
            b_size_bytes + e_size_bytes + m_size_bytes + b_bytes + e_bytes + m_bytes
        )
        expected_result = pow(b,e,m)
        cairo_result = (await modexp.test__modexp_impl(bytes_array).call()).result[0]
        cairo_uint256 = uint256_to_int(cairo_result.low,cairo_result.high)
        assert expected_result == cairo_uint256
