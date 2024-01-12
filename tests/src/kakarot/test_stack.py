class TestStack:
    class TestPeek:
        async def test_should_return_stack_at_given_index__when_value_is_0(
            self, cairo_run
        ):
            cairo_run("test__peek__should_return_stack_at_given_index__when_value_is_0")

        async def test_should_return_stack_at_given_index__when_value_is_1(
            self, cairo_run
        ):
            cairo_run("test__peek__should_return_stack_at_given_index__when_value_is_1")

    class TestInit:
        async def test_should_return_an_empty_stack(self, cairo_run):
            cairo_run("test__init__should_return_an_empty_stack")

    class TestPush:
        async def test_should_add_an_element_to_the_stack(self, cairo_run):
            cairo_run("test__push__should_add_an_element_to_the_stack")

    class TestPop:
        async def test_should_pop_an_element_to_the_stack(self, cairo_run):
            cairo_run("test__pop__should_pop_an_element_to_the_stack")

        async def test_should_pop_N_elements_to_the_stack(self, cairo_run):
            cairo_run("test__pop__should_pop_N_elements_to_the_stack")

    class TestSwap:
        async def test_should_swap_2_stacks(self, cairo_run):
            cairo_run("test__swap__should_swap_2_stacks")
