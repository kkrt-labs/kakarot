import pytest

from tests.utils.constants import LAST_PRECOMPILE_ADDRESS


class TestPrecompiles:
    class TestRun:
        @pytest.mark.parametrize(
            "address,error_message",
            [
                (0x0, "Kakarot: UnknownPrecompile 0"),
                (0x6, "Kakarot: NotImplementedPrecompile 6"),
                (0x7, "Kakarot: NotImplementedPrecompile 7"),
                (0x8, "Kakarot: NotImplementedPrecompile 8"),
                (0x0A, "Kakarot: NotImplementedPrecompile :"),
            ],
        )
        def test__precompiles_run(self, cairo_run, address, error_message):
            *return_data, reverted = cairo_run("test__precompiles_run", address=address)
            assert bytes(return_data).decode() == error_message
            assert reverted

    class TestIsPrecompile:
        @pytest.mark.parametrize("address", range(1, 12))
        def test__is_precompile_should_return_true_up_to_10(self, cairo_run, address):
            output = cairo_run("test__is_precompile", address=address)
            assert output[0] == (address <= LAST_PRECOMPILE_ADDRESS)
