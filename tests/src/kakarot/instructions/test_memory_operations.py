import pytest

from kakarot_scripts.utils.uint256 import int_to_uint256
from hypothesis import given
from hypothesis.strategies import lists, integers

from starkware.cairo.lang.cairo_constants import DEFAULT_PRIME



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

    class TestMcopy:

        @given(
            memory_init_state=lists(integers(min_value=0, max_value=255), min_size=1, max_size=100),
            size_mcopy=integers(min_value=1, max_value=100),
            src_offset_mcopy=integers(min_value=0, max_value=100),
            dst_offset_mcopy=integers(min_value=0, max_value=100),
        )
        def test_should_copy_a_value_from_memory(self, cairo_run, memory_init_state, size_mcopy, src_offset_mcopy, dst_offset_mcopy):
            (evm, memory) = cairo_run(
                "test__exec_mcopy",
                memory_init_state=memory_init_state,
                size_mcopy=int_to_uint256(size_mcopy),
                src_offset_mcopy=int_to_uint256(src_offset_mcopy),
                dst_offset_mcopy=int_to_uint256(dst_offset_mcopy),
            )
            memory_init_state_expansion = memory_init_state + [0] * (dst_offset_mcopy + size_mcopy - len(memory_init_state))
            segment_to_copy = memory_init_state_expansion[dst_offset_mcopy:dst_offset_mcopy+size_mcopy]
            expected_memory_state = memory_init_state_expansion[:dst_offset_mcopy] + segment_to_copy + memory_init_state_expansion[dst_offset_mcopy+size_mcopy:]
            words_len = (len(expected_memory_state) + 31) // 32
            expected_memory_state = "".join([f"{byte:02x}" for byte in expected_memory_state]) + "00" * (words_len * 32 - len(expected_memory_state))
            assert memory == expected_memory_state

        @given(
            memory_init_state=lists(integers(min_value=0, max_value=255), min_size=1, max_size=100),
            size_mcopy = integers(min_value=2**128 - 31, max_value=DEFAULT_PRIME - 1),
            src_offset_mcopy=integers(min_value=0, max_value=100),
            dst_offset_mcopy=integers(min_value=0, max_value=100),
        )
        def test_should_fail_if_memory_expansion_to_large(self, cairo_run, memory_init_state, size_mcopy, src_offset_mcopy, dst_offset_mcopy):
            (evm, memory) = cairo_run(
                "test__exec_mcopy",
                memory_init_state=memory_init_state,
                size_mcopy=int_to_uint256(size_mcopy),
                src_offset_mcopy=int_to_uint256(src_offset_mcopy),
                dst_offset_mcopy=int_to_uint256(dst_offset_mcopy),
            )
            assert evm["reverted"] == 2
            assert b"Kakarot: outOfGas left" in bytes(evm["return_data"])
