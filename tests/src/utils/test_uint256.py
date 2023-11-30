import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture
async def uint256(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/utils/test_uint256.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestUint256:
    class TestUint256ToUint160:
        @pytest.mark.parametrize("n", [0, 2**128, 2**160 - 1, 2**160, 2**256])
        async def test_should_cast_value(self, uint256, n):
            assert (
                n % 2**160
                == (
                    await uint256.test__uint256_to_uint160(int_to_uint256(n)).call()
                ).result.uint160
            )
