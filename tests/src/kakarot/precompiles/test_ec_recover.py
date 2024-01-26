import pytest


@pytest.mark.EC_RECOVER
class TestEcRecover:
    def test_should_fail_when_input_len_is_not_128(self, cairo_run):
        output = cairo_run("test_should_fail_when_input_len_is_not_128")
        assert bytes(output) == b"Precompile: wrong input_len"

    def test_should_fail_when_recovery_identifier_is_neither_27_nor_28(self, cairo_run):
        output = cairo_run(
            "test_should_fail_when_recovery_identifier_is_neither_27_nor_28"
        )
        assert bytes(output) == b"Precompile: flag error"

    def test_should_return_evm_address_in_bytes32(self, cairo_run):
        cairo_run("test_should_return_evm_address_in_bytes32")

    def test_should_return_evm_address_for_playground_example(self, cairo_run):
        cairo_run("test_should_return_evm_address_for_playground_example")
