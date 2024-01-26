import random

import pytest


@pytest.mark.EC_ADD
class TestEcAdd:
    @pytest.mark.parametrize(
        "calldata_len",
        [128],
        ids=["calldata_len128"],
    )
    def test_ecadd(self, cairo_run, calldata_len):
        random.seed(0)
        calldata = [random.randint(0, 255) for _ in range((calldata_len))]
        cairo_run("test__ecadd_impl", calldata=calldata)
