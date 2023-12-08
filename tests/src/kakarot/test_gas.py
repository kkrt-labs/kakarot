import pytest
import pytest_asyncio
from ethereum.shanghai.vm.gas import calculate_memory_gas_cost
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def gas(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_gas.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestGas:
    class TestCost:
        @pytest.mark.parametrize("max_offset", [0, 0xFF, 0xFFFF, 0xFFFFFF, 0xFFFFFFFF])
        async def test_should_return_same_as_execution_specs(self, gas, max_offset):
            assert (
                calculate_memory_gas_cost(max_offset)
                == (
                    await gas.test__memory_cost((max_offset + 31) // 32).call()
                ).result.cost
            )
