import pytest


@pytest.mark.asyncio(scope="session")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        async def test_should_increase_cairo_counter(self, owner):
            pass
