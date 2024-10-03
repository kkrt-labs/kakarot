import pytest


class TestSwapOperations:
    @pytest.mark.parametrize("i", range(1, 17))
    def test__exec_swap(self, cairo_run, i):
        stack = [[v, 0] for v in range(17)]
        output = cairo_run("test__exec_swap", i=i, initial_stack=stack)
        stack[i], stack[0] = stack[0], stack[i]
        assert output == [hex(i[0]) for i in stack][::-1]
