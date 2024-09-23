import pytest
import pytest_asyncio
from ethereum.base_types import U256, Uint
from ethereum.cancun.vm.exceptions import OutOfGasError
from ethereum.crypto.alt_bn128 import ALT_BN128_PRIME, BNF, BNP
from hypothesis import given, settings
from hypothesis.strategies import integers

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="package")
async def evm_precompiles(owner):
    return await deploy(
        "EvmPrecompiles",
        "EvmPrecompiles",
        caller_eoa=owner.starknet_contract,
    )


def ref_alt_bn128_add(x0, y0, x1, y1):
    x0_value = U256.from_signed(x0)
    y0_value = U256.from_signed(y0)
    x1_value = U256.from_signed(x1)
    y1_value = U256.from_signed(y1)

    for i in (x0_value, y0_value, x1_value, y1_value):
        if i >= ALT_BN128_PRIME:
            raise OutOfGasError

    try:
        p0 = BNP(BNF(x0_value), BNF(y0_value))
        p1 = BNP(BNF(x1_value), BNF(y1_value))
    except ValueError:
        raise OutOfGasError from None

    p = p0 + p1

    x_bytes = p.x.to_be_bytes32()
    y_bytes = p.y.to_be_bytes32()

    x = Uint(int.from_bytes(x_bytes, "big"))
    y = Uint(int.from_bytes(y_bytes, "big"))

    return [x, y]


def ref_alt_bn128_mul(x0, y0, s):
    x0_value = U256.from_signed(x0)
    y0_value = U256.from_signed(y0)
    U256.from_signed(s)

    for i in (x0_value, y0_value):
        if i >= ALT_BN128_PRIME:
            raise OutOfGasError

    try:
        p0 = BNP(BNF(x0_value), BNF(y0_value))
    except ValueError:
        raise OutOfGasError from None

    p = p0.mul_by(s)

    x_bytes = p.x.to_be_bytes32()
    y_bytes = p.y.to_be_bytes32()

    x = Uint(int.from_bytes(x_bytes, "big"))
    y = Uint(int.from_bytes(y_bytes, "big"))

    return [x, y]


@pytest.mark.asyncio(scope="package")
@pytest.mark.EvmPrecompiles
# @pytest.mark.xfail(reason="Katana doesn't support new builtins")
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
            try:
                expected = ref_alt_bn128_add(x0, y0, x1, y1)
                result = await evm_precompiles.ecAdd(x0, y0, x1, y1)
                assert result[0] is True
                assert result[1:] == expected
            except OutOfGasError:
                result = await evm_precompiles.ecAdd(x0, y0, x1, y1)
                assert result[0] is False

        async def test_should_return_ec_add_point_at_infinity(self, evm_precompiles):
            try:
                expected = ref_alt_bn128_add(0, 0, 0, 0)
                result = await evm_precompiles.ecAdd(0, 0, 0, 0)
                assert result[0] is True
                assert result[1:] == expected
            except OutOfGasError:
                result = await evm_precompiles.ecAdd(0, 0, 0, 0)
                assert result[0] is False

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
            try:
                expected = ref_alt_bn128_mul(x0, y0, s)
                result = await evm_precompiles.ecMul(x0, y0, s)
                assert result[0] is True
                assert result[1:] == expected
            except OutOfGasError:
                result = await evm_precompiles.ecMul(x0, y0, s)
                assert result[0] is False

        async def test_should_return_ec_mul_point_at_infinity(self, evm_precompiles):
            try:
                expected = ref_alt_bn128_mul(0, 0, 0)
                result = await evm_precompiles.ecMul(0, 0, 0)
                assert result[0] is True
                assert result[1:] == expected
            except OutOfGasError:
                result = await evm_precompiles.ecMul(0, 0, 0)
                assert result[0] is False
