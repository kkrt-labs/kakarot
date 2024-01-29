import pytest


class TestMemoryOperations:
    class TestPc:
        @pytest.mark.parametrize("increment", list(range(1, 15)))
        def test_should_update_after_incrementing(self, cairo_run, increment):
            cairo_run(
                "test__exec_pc__should_return_evm_program_counter", increment=increment
            )

    class TestPop:
        def test_should_pop_an_item_from_execution_context(self, cairo_run):
            cairo_run("test__exec_pop_should_pop_an_item_from_execution_context")

    class TestMload:
        def test_should_load_a_value_from_memory(self, cairo_run):
            cairo_run("test__exec_mload_should_load_a_value_from_memory")

        def test_should_load_a_value_from_memory_with_memory_expansion(self, cairo_run):
            cairo_run(
                "test__exec_mload_should_load_a_value_from_memory_with_memory_expansion"
            )

        def test_should_load_a_value_from_memory_with_offset_larger_than_msize(
            self, cairo_run
        ):
            cairo_run(
                "test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize"
            )
