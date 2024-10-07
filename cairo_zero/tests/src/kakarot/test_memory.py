import pytest


class TestMemory:
    class TestInit:
        def test_should_return_an_empty_memory(self, cairo_run):
            cairo_run("test__init__should_return_an_empty_memory")

    class TestStore:
        def test_should_add_an_element_to_the_memory(self, cairo_run):
            cairo_run("test__store__should_add_an_element_to_the_memory")

    class TestLoad:
        @pytest.mark.parametrize(
            "offset, low, high",
            [
                (8, 2 * 256**8, 256**8),
                (7, 2 * 256**7, 256**7),
                (23, 3 * 256**7, 2 * 256**7),
                (33, 4 * 256**1, 3 * 256**1),
                (63, 0, 4 * 256**15),
                (500, 0, 0),
            ],
        )
        async def test_should_load_an_element_from_the_memory_with_offset(
            self, cairo_run, offset, low, high
        ):
            cairo_run(
                "test__load__should_load_an_element_from_the_memory_with_offset",
                offset=offset,
                low=low,
                high=high,
            )

        def test_should_expand_memory_and_return_element(self, cairo_run):
            cairo_run("test__load__should_return_element")
