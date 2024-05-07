import pytest

from tests.utils.constants import (
    FIRST_ROLLUP_PRECOMPILE_ADDRESS,
    LAST_ETHEREUM_PRECOMPILE_ADDRESS,
    LAST_ROLLUP_PRECOMPILE_ADDRESS,
)


class TestPrecompiles:
    class TestRun:
        @pytest.mark.parametrize(
            "address, error_message",
            [
                (0x0, "Kakarot: UnknownPrecompile 0"),
                (0x6, "Kakarot: NotImplementedPrecompile 6"),
                (0x7, "Kakarot: NotImplementedPrecompile 7"),
                (0x8, "Kakarot: NotImplementedPrecompile 8"),
                (0x0A, "Kakarot: NotImplementedPrecompile 10"),
            ],
        )
        def test__precompiles_run_should_fail(self, cairo_run, address, error_message):
            return_data, reverted, _ = cairo_run(
                "test__precompiles_run", address=address, input=[]
            )
            assert bytes(return_data).decode() == error_message
            assert reverted

        # input data from <https://github.com/ulerdogan/go-ethereum/blob/75062a6998e4e3fbb4cdb623b8b02e79e7b8f965/core/vm/contracts_test.go#L401-L410>
        @pytest.mark.parametrize(
            "address, input_data",
            [
                (
                    0x100,
                    bytes.fromhex(
                        "4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4da73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d604aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff37618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e"
                    ),
                )
            ],
        )
        def test__p256_verify_precompile_should_succeed(
            self, cairo_run, address, input_data
        ):
            return_data, reverted, gas_used = cairo_run(
                "test__precompiles_run", address=address, input=input_data
            )
            assert not reverted
            assert len(return_data) == 32
            assert int.from_bytes(return_data, "big") == 1
            assert gas_used == 3450

        @pytest.mark.parametrize(
            "address, input_data",
            [
                (
                    0x100,
                    bytes.fromhex(
                        "5cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4da73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d604aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff37618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e"
                    ),
                )
            ],
        )
        def test__p256_verify_precompile_should_fail(
            self, cairo_run, address, input_data
        ):
            return_data, reverted, gas_used = cairo_run(
                "test__precompiles_run", address=address, input=input_data
            )
            assert not reverted
            assert len(return_data) == 0
            assert gas_used == 3450

    class TestIsPrecompile:
        @pytest.mark.parametrize(
            "address", range(0, LAST_ETHEREUM_PRECOMPILE_ADDRESS + 2)
        )
        def test__is_precompile_ethereum_precompiles(self, cairo_run, address):
            result = cairo_run("test__is_precompile", address=address)
            assert result == (address in range(1, LAST_ETHEREUM_PRECOMPILE_ADDRESS + 1))

        @pytest.mark.parametrize(
            "address",
            range(FIRST_ROLLUP_PRECOMPILE_ADDRESS, LAST_ROLLUP_PRECOMPILE_ADDRESS + 2),
        )
        def test__is_precompile_rollup_precompiles(self, cairo_run, address):
            result = cairo_run("test__is_precompile", address=address)
            assert result == (
                address
                in range(
                    FIRST_ROLLUP_PRECOMPILE_ADDRESS, LAST_ROLLUP_PRECOMPILE_ADDRESS + 1
                )
            )
