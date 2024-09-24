import pytest
import pytest_asyncio
from ethereum.base_types import U256, Uint
from ethereum.crypto.alt_bn128 import ALT_BN128_PRIME, BNF, BNP
from hypothesis import given, settings
from hypothesis.strategies import integers

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="package")
async def evm_precompiles():
    return await deploy(
        "EvmPrecompiles",
        "EvmPrecompiles",
    )


def ref_alt_bn128_add(x0, y0, x1, y1):
    """
    # ruff: noqa: D401
    Reference implementation of the alt_bn128_add precompile.
    Source: https://github.com/ethereum/execution-specs/blob/07f5747a43d62ef7f203d41d77005cb15ca5e434/src/ethereum/cancun/vm/precompiled_contracts/alt_bn128.py#L32-L103.
    """
    x0_value = U256.from_signed(x0)
    y0_value = U256.from_signed(y0)
    x1_value = U256.from_signed(x1)
    y1_value = U256.from_signed(y1)

    for i in (x0_value, y0_value, x1_value, y1_value):
        if i >= ALT_BN128_PRIME:
            return [False, 0, 0]

    try:
        p0 = BNP(BNF(x0_value), BNF(y0_value))
        p1 = BNP(BNF(x1_value), BNF(y1_value))
    except ValueError:
        return [False, 0, 0]

    p = p0 + p1

    x_bytes = p.x.to_be_bytes32()
    y_bytes = p.y.to_be_bytes32()

    x = Uint(int.from_bytes(x_bytes, "big"))
    y = Uint(int.from_bytes(y_bytes, "big"))

    return [True, x, y]


def ref_alt_bn128_mul(x0, y0, s):
    """
    # ruff: noqa: D401
    Reference implementation of the alt_bn128_mul precompile.
    Source: https://github.com/ethereum/execution-specs/blob/07f5747a43d62ef7f203d41d77005cb15ca5e434/src/ethereum/cancun/vm/precompiled_contracts/alt_bn128.py#L32-L103.
    """
    x0_value = U256.from_signed(x0)
    y0_value = U256.from_signed(y0)
    s_value = U256.from_signed(s)

    for i in (x0_value, y0_value):
        if i >= ALT_BN128_PRIME:
            return [False, 0, 0]

    try:
        p0 = BNP(BNF(x0_value), BNF(y0_value))
    except ValueError:
        return [False, 0, 0]

    p = p0.mul_by(s_value)

    x_bytes = p.x.to_be_bytes32()
    y_bytes = p.y.to_be_bytes32()

    x = Uint(int.from_bytes(x_bytes, "big"))
    y = Uint(int.from_bytes(y_bytes, "big"))

    return [True, x, y]


@pytest.mark.asyncio(scope="package")
@pytest.mark.EvmPrecompiles
class TestEvmPrecompiles:
    class TestEcAdd:
        @given(
            x0=integers(min_value=0, max_value=ALT_BN128_PRIME - 1),
            y0=integers(min_value=0, max_value=ALT_BN128_PRIME - 1),
            x1=integers(min_value=0, max_value=ALT_BN128_PRIME - 1),
            y1=integers(min_value=0, max_value=ALT_BN128_PRIME - 1),
        )
        @settings(max_examples=10)
        async def test_should_return_ec_add_with_coordinates(
            self, evm_precompiles, x0, y0, x1, y1
        ):
            expected = ref_alt_bn128_add(x0, y0, x1, y1)
            result = await evm_precompiles.ecAdd(x0, y0, x1, y1)
            assert result == expected

        async def test_should_return_ec_add_point_at_infinity(self, evm_precompiles):
            expected = ref_alt_bn128_add(0, 0, 0, 0)
            result = await evm_precompiles.ecAdd(0, 0, 0, 0)
            assert result == expected

    class TestEcMul:
        @given(
            x0=integers(min_value=0, max_value=ALT_BN128_PRIME - 1),
            y0=integers(min_value=0, max_value=ALT_BN128_PRIME - 1),
            s=integers(min_value=0, max_value=2**256 - 1),
        )
        @settings(max_examples=10)
        async def test_should_return_ec_mul_with_coordinates(
            self, evm_precompiles, x0, y0, s
        ):
            expected = ref_alt_bn128_mul(x0, y0, s)
            result = await evm_precompiles.ecMul(x0, y0, s)
            assert result == expected

        async def test_should_return_ec_mul_point_at_infinity(self, evm_precompiles):
            expected = ref_alt_bn128_mul(0, 0, 0)
            result = await evm_precompiles.ecMul(0, 0, 0)
            assert result == expected
