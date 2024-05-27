import pytest
from starkware.starknet.public.abi import get_selector_from_name

from tests.utils.constants import (
    CAIRO_PRECOMPILE_GAS,
    FIRST_KAKAROT_PRECOMPILE_ADDRESS,
    FIRST_ROLLUP_PRECOMPILE_ADDRESS,
    LAST_ETHEREUM_PRECOMPILE_ADDRESS,
    LAST_KAKAROT_PRECOMPILE_ADDRESS,
    LAST_ROLLUP_PRECOMPILE_ADDRESS,
)
from tests.utils.syscall_handler import SyscallHandler


class TestPrecompiles:
    class TestRun:

        class TestEthereumPrecompiles:
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
            def test__precompiles_run_should_fail(
                self, cairo_run, address, error_message
            ):
                return_data, reverted, _ = cairo_run(
                    "test__precompiles_run", address=address, input=[]
                )
                assert bytes(return_data).decode() == error_message
                assert reverted

        class TestRollupPrecompiles:
            # input data from <https://github.com/ulerdogan/go-ethereum/blob/75062a6998e4e3fbb4cdb623b8b02e79e7b8f965/core/vm/contracts_test.go#L401-L410>
            @pytest.mark.parametrize(
                "address, input_data, expected_return_data",
                [
                    (
                        0x100,
                        bytes.fromhex(
                            "4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4da73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d604aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff37618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e"
                        ),
                        [0] * 31 + [1],
                    ),
                    (
                        0x100,
                        bytes.fromhex(
                            "5cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4da73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d604aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff37618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e"
                        ),
                        [],
                    ),
                ],
            )
            def test__p256_verify_precompile(
                self, cairo_run, address, input_data, expected_return_data
            ):
                return_data, reverted, gas_used = cairo_run(
                    "test__precompiles_run", address=address, input=input_data
                )
                assert not reverted
                assert return_data == expected_return_data
                assert gas_used == 3450

        class TestKakarotPrecompiles:
            @SyscallHandler.patch("ICairo.inc", lambda addr, data: [])
            @pytest.mark.parametrize(
                "address, input_data, expected_return_data, expected_reverted",
                [
                    (
                        0x75001,
                        bytes.fromhex("0abcdef0"),
                        list(b"Kakarot: OutOfBoundsRead"),
                        True,
                    ),  # invalid input
                    (
                        0x75001,
                        bytes.fromhex(
                            "b3eb2c1b"
                            + f"{0xc0de:064x}"
                            + f"{get_selector_from_name('inc'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x00:064x}"  # data_len
                        ),
                        [],
                        False,
                    ),  # call_contract
                    (
                        0x75001,
                        bytes.fromhex(
                            "5a9af197"
                            + f"{0xc0de:064x}"
                            + f"{get_selector_from_name('get'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x01:064x}"  # data_len
                            + f"{0x01:064x}"  # data
                        ),
                        [1],
                        False,
                    ),  # library_call
                ],
            )
            def test__cairo_precompiles(
                self,
                cairo_run,
                address,
                input_data,
                expected_return_data,
                expected_reverted,
            ):
                with SyscallHandler.patch(
                    "ICairo.get", lambda addr, data: expected_return_data
                ):
                    return_data, reverted, gas_used = cairo_run(
                        "test__precompiles_run", address=address, input=input_data
                    )
                assert (reverted != 0) == expected_reverted
                assert return_data == expected_return_data
                assert gas_used == CAIRO_PRECOMPILE_GAS

                return

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

        @pytest.mark.parametrize(
            "address",
            range(
                FIRST_KAKAROT_PRECOMPILE_ADDRESS, LAST_KAKAROT_PRECOMPILE_ADDRESS + 2
            ),
        )
        def test__is_precompile_kakarot_precompiles(self, cairo_run, address):
            result = cairo_run("test__is_precompile", address=address)
            assert result == (
                address
                in range(
                    FIRST_KAKAROT_PRECOMPILE_ADDRESS,
                    LAST_KAKAROT_PRECOMPILE_ADDRESS + 1,
                )
            )
