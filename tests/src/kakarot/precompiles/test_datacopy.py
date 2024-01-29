import random

import pytest


class TestDataCopy:
    @pytest.mark.parametrize("calldata_len", [32])
    async def test_datacopy(self, cairo_run, calldata_len):
        random.seed(0)
        calldata = [random.randint(0, 255) for _ in range(calldata_len)]
        cairo_run("test__datacopy_impl", calldata=calldata)
