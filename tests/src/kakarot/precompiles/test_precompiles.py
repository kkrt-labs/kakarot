from unittest.mock import PropertyMock, patch

import pytest
from eth_abi import encode
from starkware.starknet.public.abi import get_selector_from_name

from tests.utils.constants import (
    CAIRO_MESSAGE_GAS,
    CAIRO_PRECOMPILE_GAS,
    FIRST_KAKAROT_PRECOMPILE_ADDRESS,
    FIRST_ROLLUP_PRECOMPILE_ADDRESS,
    LAST_ETHEREUM_PRECOMPILE_ADDRESS,
    LAST_KAKAROT_PRECOMPILE_ADDRESS,
    LAST_ROLLUP_PRECOMPILE_ADDRESS,
)
from tests.utils.syscall_handler import SyscallHandler

AUTHORIZED_CALLER = 0xA7071ED
UNAUTHORIZED_CALLER = 0xC0C0C0


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
            @pytest.mark.parametrize(
                "address, eoa_caller_address, input_data, expected_return_data",
                (
                    (
                        0x75001,
                        AUTHORIZED_CALLER,
                        bytes.fromhex(
                            "b3eb2c1b"
                            + f"{0xc0de:064x}"
                            + f"{get_selector_from_name('inc'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x00:064x}"  # data_len
                        ),
                        b"",
                    ),  # call_contract
                    (
                        0x75001,
                        AUTHORIZED_CALLER,
                        bytes.fromhex(
                            "b3eb2c1b"
                            + f"{0xc0de:064x}"
                            + f"{get_selector_from_name('get'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x01:064x}"  # data_len
                            + f"{0x01:064x}"  # data
                        ),
                        bytes.fromhex(f"{0x01:064x}"),
                    ),  # call_contract with return data
                ),
                ids=[
                    "call_contract",
                    "call_contract_w_returndata",
                ],
            )
            @SyscallHandler.patch(
                "Kakarot_authorized_cairo_precompiles_callers", AUTHORIZED_CALLER, 1
            )
            @patch(
                "tests.utils.syscall_handler.SyscallHandler.caller_address",
                new_callable=PropertyMock,
            )
            def test_should_pass_when_starknet_origin_zero(
                self,
                mock_caller_address,
                cairo_run,
                address,
                input_data,
                eoa_caller_address,
                expected_return_data,
            ):
                """
                Tests the behavior when the get_caller_address() in Kakarot is zero, meaning that the caller
                of Kakarot is either a L1 Handler OR it's a view call (eth_call).
                """
                mock_caller_address.return_value = 0
                cairo_return_data = [
                    int.from_bytes(expected_return_data[i : i + 32], "big")
                    for i in range(0, len(expected_return_data), 32)
                ]
                with SyscallHandler.patch(
                    "ICairo.get",
                    lambda addr, data: cairo_return_data,
                ), SyscallHandler.patch("ICairo.inc", lambda addr, data: []):
                    return_data, reverted, gas_used = cairo_run(
                        "test__precompiles_run",
                        address=address,
                        input=input_data,
                        caller_address=eoa_caller_address,
                    )
                assert not bool(reverted)
                assert bytes(return_data) == expected_return_data
                assert gas_used == (
                    CAIRO_PRECOMPILE_GAS
                    if eoa_caller_address == AUTHORIZED_CALLER
                    else 0
                )
                return

            @SyscallHandler.patch("ICairo.inc", lambda addr, data: [])
            @SyscallHandler.patch(
                "Kakarot_authorized_cairo_precompiles_callers", AUTHORIZED_CALLER, 1
            )
            @pytest.mark.parametrize(
                "address, caller_address, input_data, expected_return_data, expected_reverted",
                [
                    (
                        0x75001,
                        AUTHORIZED_CALLER,
                        bytes.fromhex("0abcdef0"),
                        b"Kakarot: OutOfBoundsRead",
                        True,
                    ),  # invalid input
                    (
                        0x75001,
                        AUTHORIZED_CALLER,
                        bytes.fromhex(
                            "b3eb2c1b"
                            + f"{0xc0de:064x}"
                            + f"{get_selector_from_name('inc'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x00:064x}"  # data_len
                        ),
                        b"",
                        False,
                    ),  # call_contract
                    (
                        0x75001,
                        AUTHORIZED_CALLER,
                        bytes.fromhex(
                            "b3eb2c1b"
                            + f"{0xc0de:064x}"
                            + f"{get_selector_from_name('get'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x01:064x}"  # data_len
                            + f"{0x01:064x}"  # data
                        ),
                        bytes.fromhex(f"{0x01:064x}"),
                        False,
                    ),  # call_contract with return data
                    (
                        0x75001,
                        AUTHORIZED_CALLER,
                        bytes.fromhex(
                            "5a9af197"
                            + f"{0xc0de:064x}"
                            + f"{get_selector_from_name('get'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x01:064x}"  # data_len
                            + f"{0x00:064x}"  # data
                        ),
                        bytes.fromhex(f"{0x00:064x}"),
                        False,
                    ),  # library call
                    (
                        0x75001,
                        UNAUTHORIZED_CALLER,
                        bytes.fromhex("0abcdef0"),
                        b"Kakarot: unauthorizedPrecompile",
                        True,
                    ),  # invalid caller
                ],
                ids=[
                    "invalid_input",
                    "call_contract",
                    "call_contract_w_returndata",
                    "library_call",
                    "invalid_caller",
                ],
            )
            def test__cairo_precompiles(
                self,
                cairo_run,
                address,
                caller_address,
                input_data,
                expected_return_data,
                expected_reverted,
            ):
                # The expected returndata is a list of 32-byte words where each word is a felt returned by the precompile.
                cairo_return_data = [
                    int.from_bytes(expected_return_data[i : i + 32], "big")
                    for i in range(0, len(expected_return_data), 32)
                ]
                # Expected output is [0] if no return data is expected,
                # [len(retdata), retdata] otherwise.
                with SyscallHandler.patch(
                    "IAccount.execute_starknet_call",
                    lambda addr, data: (
                        [len(cairo_return_data), *cairo_return_data]
                        if len(cairo_return_data) != 0
                        else [0]
                    ),
                ), SyscallHandler.patch(
                    "ICairo.get",
                    lambda addr, data: cairo_return_data,
                ):
                    return_data, reverted, gas_used = cairo_run(
                        "test__precompiles_run",
                        address=address,
                        input=input_data,
                        caller_address=caller_address,
                    )
                assert bool(reverted) == expected_reverted
                assert bytes(return_data) == expected_return_data
                assert gas_used == (
                    CAIRO_PRECOMPILE_GAS if caller_address == AUTHORIZED_CALLER else 0
                )
                return

        @pytest.mark.parametrize(
            "address, input_data, to_address, payload, expected_reverted",
            [
                (
                    0x75002,
                    encode(["uint160", "bytes"], [0xC0DE, encode(["uint128"], [0x2A])]),
                    0xC0DE,
                    list(bytes.fromhex(f"{0x2a:064x}")),
                    False,
                ),
                (
                    0x75002,
                    encode(["uint160", "bytes"], [0xC0DE, 0x2A.to_bytes(1, "big")]),
                    0xC0DE,
                    list(0x2A.to_bytes(1, "big")),
                    False,
                ),
                # case with data_len not matching the actual data length
                (
                    0x75002,
                    bytes.fromhex(
                        f"{0xc0de:064x}"
                        + f"{0x40:064x}"
                        + f"{0x20:064x}"
                        + f"{0x2a:032x}"
                    ),
                    0xC0DE,
                    [],
                    True,
                ),
                # case with input data too short
                (
                    0x75002,
                    bytes.fromhex(f"{0xc0de:064x}" + f"{0x40:064x}"),
                    0xC0DE,
                    [],
                    True,
                ),
            ],
            ids=[
                "ok_32_bytes_data",
                "ok_1_bytes_data",
                "ko_data_len_not_matching_actual_length",
                "ko_input_too_short",
            ],
        )
        class TestKakarotMessaging:
            def test__cairo_message(
                self,
                cairo_run,
                address,
                input_data,
                to_address,
                payload,
                expected_reverted,
            ):
                address = 0x75002
                return_data, reverted, gas_used = cairo_run(
                    "test__precompiles_run",
                    address=address,
                    input=input_data,
                )
                if expected_reverted:
                    assert reverted
                    return

                SyscallHandler.mock_send_message_to_l1.assert_any_call(
                    to_address=to_address, payload=payload
                )
                assert gas_used == CAIRO_MESSAGE_GAS

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
