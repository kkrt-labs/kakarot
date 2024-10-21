import pytest


class TestDupOperations:
    @pytest.mark.parametrize("i", range(1, 17))
    def test__exec_dup(self, cairo_run, i):
        stack = [[v, 0] for v in range(16)]
        output = cairo_run("test__exec_dup", initial_stack=stack, i=i)
        assert output == [hex(i[0]) for i in stack][::-1] + [hex(stack[i - 1][0])]
