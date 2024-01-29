import pytest


@pytest.mark.EC_RECOVER
class TestEcRecover:
    def test_should_return_evm_address_in_bytes32(self, cairo_run):
        cairo_run("test_should_return_evm_address_in_bytes32")

    def test_should_return_evm_address_for_playground_example(self, cairo_run):
        cairo_run("test_should_return_evm_address_for_playground_example")
