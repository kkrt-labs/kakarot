import pytest
import pytest_asyncio
from ethereum.base_types import U256, Uint
from ethereum.crypto.alt_bn128 import ALT_BN128_PRIME, BNF, BNP
from ethereum.cancun.vm.exceptions import OutOfGasError

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

    x = Uint(x_bytes)
    y = Uint(y_bytes)

    return x, y


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

    x = Uint(x_bytes)
    y = Uint(y_bytes)

    return x, y


@pytest.mark.asyncio(scope="package")
@pytest.mark.EvmPrecompiles
# @pytest.mark.xfail(reason="Katana doesn't support new builtins")
class TestEvmPrecompiles:
    class TestEcAdd:
        async def test_should_return_ec_add_point_at_infinity(self, evm_precompiles):
            result = await evm_precompiles.ecAdd(0, 0, 0, 0)
            expected = ref_alt_bn128_add(0, 0, 0, 0)
            assert result == expected

        async def test_should_return_ec_add_with_coordinates(self, evm_precompiles):
            result = await evm_precompiles.ecAdd(1, 2, 1, 2)
            expected = ref_alt_bn128_add(1, 2, 1, 2)
            assert result == expected

    class TestEcMul:
        async def test_should_return_ec_mul_with_coordinates(self, evm_precompiles):
            result = await evm_precompiles.ecMul(1, 2, 2)
            expected = ref_alt_bn128_mul(1, 2, 2)
            assert result == expected

        async def test_should_return_ec_mul_point_at_infinity(self, evm_precompiles):
            result = await evm_precompiles.ecMul(0, 0, 0)
            expected = ref_alt_bn128_mul(0, 0, 0)
            assert result == expected
