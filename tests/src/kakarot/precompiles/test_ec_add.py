import hypothesis.strategies as st
import pytest
from hypothesis import given, settings


@pytest.mark.EC_ADD
class TestEcAdd:
    @given(calldata=st.binary(min_size=128, max_size=128))
    @settings(max_examples=5, deadline=None)
    def test_ecadd(self, cairo_run, calldata):
        cairo_run("test__ecadd_impl", calldata=list(calldata))
