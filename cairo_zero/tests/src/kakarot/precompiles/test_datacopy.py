import hypothesis.strategies as st
from hypothesis import given, settings


class TestDataCopy:
    @given(calldata=st.binary(max_size=100))
    @settings(max_examples=20)
    async def test_datacopy(self, cairo_run, calldata):
        cairo_run("test__datacopy_impl", calldata=list(calldata))
