import pytest
from ethereum.shanghai.vm.gas import calculate_memory_gas_cost


class TestGas:
    class TestCost:
        @pytest.mark.parametrize("max_offset", [0, 0xFF, 0xFFFF, 0xFFFFFF, 0xFFFFFFFF])
        def test_should_return_same_as_execution_specs(self, cairo_run, max_offset):
            output = cairo_run("test__memory_cost", words_len=((max_offset + 31) // 32))
            assert calculate_memory_gas_cost(max_offset) == output[0]
