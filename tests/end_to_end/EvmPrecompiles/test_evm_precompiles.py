import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="package")
async def evm_precompiles(owner):
    return await deploy(
        "EvmPrecompiles",
        "EvmPrecompiles",
        caller_eoa=owner.starknet_contract,
    )


@pytest.mark.asyncio(scope="package")
@pytest.mark.EvmPrecompiles
class TestEvmPrecompiles:
    class TestEcAdd:
        async def test_should_return_ec_add_point_at_infinity(self, evm_precompiles):
            assert await evm_precompiles.ecAdd(0, 0, 0, 0) == (0, 0)

        async def test_should_return_ec_add_with_coordinates(self, evm_precompiles):
            expected_x = (
                0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD3
            )
            expected_y = (
                0x15ED738C0E0A7C92E7845F96B2AE9C0A68A6A449E3538FC7FF3EBF7A5A18A2C4
            )
            assert await evm_precompiles.ecAdd(1, 2, 1, 2) == (expected_x, expected_y)

    class TestEcMul:
        async def test_should_return_ec_mul_with_coordinates(self, evm_precompiles):
            expected_x = (
                0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD3
            )
            expected_y = (
                0x15ED738C0E0A7C92E7845F96B2AE9C0A68A6A449E3538FC7FF3EBF7A5A18A2C4
            )
            assert await evm_precompiles.ecMul(1, 2, 2) == (expected_x, expected_y)

        async def test_should_return_ec_mul_point_at_infinity(self, evm_precompiles):
            assert await evm_precompiles.ecMul(0, 0, 0) == (0, 0)
