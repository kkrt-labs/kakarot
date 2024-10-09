from typing import List

import pytest
from py_tests.test_utils.types import U256, Stack


class TestStack:
    def test_new(self, cairo_run):
        result = cairo_run("test__stack_new", Stack)
        assert result == Stack([])

    def test_push(self, cairo_run):
        values = [U256(0x10), U256(0x20)]
        result = cairo_run("test__stack_push", Stack, values)
        assert result == Stack([U256(0x10), U256(0x20)])

    def test_pop(self, cairo_run):
        stack = [U256(0x10), U256(0x20), U256(0x30)]
        result = cairo_run("test__stack_pop", (Stack, U256), stack)
        assert result[0] == Stack([U256(0x10), U256(0x20)])
        assert result[1] == U256(0x30)

    def test_pop_n(self, cairo_run):
        stack = [U256(0x10), U256(0x20), U256(0x30), U256(0x40), U256(0x50)]
        n = 3
        result = cairo_run("test__stack_pop_n", (Stack, List[U256]), stack, n)
        assert result[0] == Stack([U256(0x10), U256(0x20)])
        assert result[1] == [U256(0x50), U256(0x40), U256(0x30)]

    def test_peek(self, cairo_run):
        stack = [U256(0x10), U256(0x20), U256(0x30)]
        index = 1
        result = cairo_run("test__stack_peek", (Stack, U256), stack, index)
        assert result[0] == Stack([U256(0x10), U256(0x20), U256(0x30)])
        assert result[1] == U256(0x20)

    def test_swap(self, cairo_run):
        stack = [U256(0x1), U256(0x2), U256(0x3), U256(0x4)]
        index = 2
        result = cairo_run("test__stack_swap", Stack, stack, index)
        assert result == Stack([U256(0x1), U256(0x4), U256(0x3), U256(0x2)])

    def test_push_when_full(self, cairo_run):
        # Create a full stack (1024 elements)
        values = [U256(i) for i in range(1024)]
        result = cairo_run("test__stack_push", Stack, values)
        assert result == Stack(values)

        # Try to push one more element
        with pytest.raises(Exception) as exc_info:
            cairo_run("test__stack_push", Stack, values + [U256(1024)])
        assert "StackOverflow" in str(exc_info.value)

    def test_pop_when_empty(self, cairo_run):
        with pytest.raises(Exception) as exc_info:
            cairo_run("test__stack_pop", (Stack, U256), [])
        assert "StackUnderflow" in str(exc_info.value)

    def test_peek_when_empty(self, cairo_run):
        with pytest.raises(Exception) as exc_info:
            cairo_run("test__stack_peek", (Stack, U256), [], 0)
        assert "StackUnderflow" in str(exc_info.value)

    def test_pop_n_underflow(self, cairo_run):
        stack = [U256(0x10), U256(0x20)]
        with pytest.raises(Exception) as exc_info:
            cairo_run("test__stack_pop_n", (Stack, List[U256]), stack, 3)
        assert "StackUnderflow" in str(exc_info.value)

    def test_swap_underflow(self, cairo_run):
        stack = [U256(0x1), U256(0x2)]
        with pytest.raises(Exception) as exc_info:
            cairo_run("test__stack_swap", Stack, stack, 2)
        assert "StackUnderflow" in str(exc_info.value)

    def test_push_multiple_and_pop_multiple(self, cairo_run):
        values = [U256(0x10), U256(0x20), U256(0x30), U256(0x40)]
        result = cairo_run("test__stack_push", Stack, values)
        assert result == Stack(values)

        result = cairo_run("test__stack_pop_n", (Stack, List[U256]), values, 2)
        assert result[0] == Stack([U256(0x10), U256(0x20)])
        assert result[1] == [U256(0x40), U256(0x30)]

    def test_peek_at_various_indices(self, cairo_run):
        stack = [U256(0x10), U256(0x20), U256(0x30), U256(0x40)]
        for i, expected in enumerate(reversed(stack)):
            result = cairo_run("test__stack_peek", (Stack, U256), stack, i)
            assert result[0] == Stack(stack)
            assert result[1] == expected

    def test_swap_various_indices(self, cairo_run):
        stack = [U256(0x1), U256(0x2), U256(0x3), U256(0x4)]
        for i in range(1, len(stack)):
            expected = stack.copy()
            expected[-1], expected[-1 - i] = expected[-1 - i], expected[-1]
            result = cairo_run("test__stack_swap", Stack, stack, i)
            assert result == Stack(expected)

    def test_push_pop_peek_combination(self, cairo_run):
        # Push some values
        values = [U256(0x10), U256(0x20), U256(0x30)]
        result = cairo_run("test__stack_push", Stack, values)
        assert result == Stack(values)

        # Peek at the top
        result = cairo_run("test__stack_peek", (Stack, U256), values, 0)
        assert result[0] == Stack(values)
        assert result[1] == U256(0x30)

        # Pop one value
        result = cairo_run("test__stack_pop", (Stack, U256), values)
        assert result[0] == Stack([U256(0x10), U256(0x20)])
        assert result[1] == U256(0x30)

        # Push another value
        result = cairo_run(
            "test__stack_push", Stack, [U256(0x10), U256(0x20), U256(0x40)]
        )
        assert result == Stack([U256(0x10), U256(0x20), U256(0x40)])

        # Peek at index 1
        result = cairo_run(
            "test__stack_peek", (Stack, U256), [U256(0x10), U256(0x20), U256(0x40)], 1
        )
        assert result[0] == Stack([U256(0x10), U256(0x20), U256(0x40)])
        assert result[1] == U256(0x20)
