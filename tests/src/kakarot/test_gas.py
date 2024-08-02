import pytest
from ethereum.shanghai.vm.gas import (
    calculate_gas_extend_memory,
    calculate_memory_gas_cost,
)
from hypothesis import given
from hypothesis.strategies import integers


class TestGas:
    class TestCost:
        @given(max_offset=integers(min_value=0, max_value=0xFFFFFF))
        def test_should_return_same_as_execution_specs(self, cairo_run, max_offset):
            output = cairo_run("test__memory_cost", words_len=(max_offset + 31) // 32)
            assert calculate_memory_gas_cost(max_offset) == output

        @given(
            bytes_len=integers(min_value=0, max_value=2**128 - 1),
            added_offset=integers(min_value=0, max_value=2**128 - 1),
        )
        def test_should_return_correct_expansion_cost(
            self, cairo_run, bytes_len, added_offset
        ):
            max_offset = bytes_len + added_offset
            output = cairo_run(
                "test__memory_expansion_cost",
                words_len=(bytes_len + 31) // 32,
                max_offset=max_offset,
            )
            cost_before = calculate_memory_gas_cost(bytes_len)
            cost_after = calculate_memory_gas_cost(max_offset)
            diff = cost_after - cost_before
            assert diff == output

        @given(
            offset_1=integers(min_value=0, max_value=0xFFFFF),
            size_1=integers(min_value=0, max_value=0xFFFFF),
            offset_2=integers(min_value=0, max_value=0xFFFFF),
            size_2=integers(min_value=0, max_value=0xFFFFF),
        )
        def test_should_return_max_expansion_cost(
            self, cairo_run, offset_1, size_1, offset_2, size_2
        ):
            output = cairo_run(
                "test__max_memory_expansion_cost",
                words_len=0,
                offset_1=offset_1,
                size_1=size_1,
                offset_2=offset_2,
                size_2=size_2,
            )
            assert (
                output
                == calculate_gas_extend_memory(
                    b"",
                    [
                        (offset_1, size_1),
                        (offset_2, size_2),
                    ],
                ).cost
            )

    class TestMessageGas:
        @pytest.mark.parametrize(
            "gas_param, gas_left, expected",
            [
                (0, 0, 0),
                (10, 100, 10),
                (100, 100, 99),
                (100, 10, 10),
            ],
        )
        def test_should_return_message_base_gas(
            self, cairo_run, gas_param, gas_left, expected
        ):
            output = cairo_run(
                "test__compute_message_call_gas", gas_param=gas_param, gas_left=gas_left
            )
            assert output == expected
