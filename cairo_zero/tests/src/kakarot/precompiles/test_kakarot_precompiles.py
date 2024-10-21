import pytest
from eth_utils import keccak
from starkware.cairo.lang.cairo_constants import DEFAULT_PRIME

CALL_CONTRACT_SOLIDITY_SELECTOR = keccak(
    text="call_contract(uint256,uint256,uint256[])"
)[:4].hex()

AUTHORIZED_CALLER_CODE = 0xA7071ED
UNAUTHORIZED_CALLER_CODE = 0xC0C0C0
CALLER_ADDRESS = 0x123ABC432


class TestKakarotPrecompiles:
    class TestParseCairoCall:

        @pytest.mark.parametrize(
            "address, selector, calldata_len_offset, calldata_len, calldata",
            [
                ("", "", "", "", b""),
                (
                    f"{DEFAULT_PRIME + 1:064x}",
                    f"{0:064x}",
                    f"{0:064x}",
                    f"{0:064x}",
                    b"",
                ),
                (
                    f"{0:064x}",
                    f"{DEFAULT_PRIME + 1:064x}",
                    f"{0:064x}",
                    f"{0:064x}",
                    b"",
                ),
                (f"{0:064x}", f"{0:064x}", f"{2**128:064x}", f"{0:064x}", b""),
                (
                    f"{0:064x}",
                    f"{0:064x}",
                    f"{0x60:064x}",
                    f"{256**2:064x}",
                    bytes([0] * 256**2),
                ),
                (
                    f"{0:064x}",
                    f"{0:064x}",
                    f"{0x60:064x}",
                    f"{0xFF:064x}",
                    bytes([0] * 0xF0),
                ),
            ],
            ids=[
                "input_too_small",
                "address_too_big",
                "selector_too_big",
                "calldata_len_offset_too_big",
                "calldata_len_more_than_two_bytes",
                "calldata_smaller_than_calldata_len",
            ],
        )
        def test_parse_cairo_call_should_fail(
            self,
            cairo_run,
            address,
            selector,
            calldata_len_offset,
            calldata_len,
            calldata,
        ):
            evm_encoded_call = (
                bytes.fromhex(address + selector + calldata_len_offset + calldata_len)
                + calldata
            )
            is_err, _, _, _, _, _ = cairo_run(
                "test__parse_cairo_call", evm_encoded_call=evm_encoded_call
            )

            assert is_err == 1

        @pytest.mark.parametrize(
            "address, selector, calldata_len_offset, calldata_len, calldata, expected_results",
            [
                (
                    f"{0xABCD:064x}",
                    f"{0x1234:064x}",
                    f"{0x60:064x}",
                    f"{0x00:064x}",
                    b"",
                    (0, 0xABCD, 0x1234, 0, [], 4 * 32),
                ),
                (
                    f"{0xABCD:064x}",
                    f"{0x1234:064x}",
                    f"{0x60:064x}",
                    f"{0x02:064x}",
                    bytes.fromhex(f"{0xDEADBEEF:064x}" + f"{0xCAFEBABE:064x}"),
                    (0, 0xABCD, 0x1234, 2, [0xDEADBEEF, 0xCAFEBABE], 6 * 32),
                ),
            ],
            ids=[
                "empty_calldata",
                "two_words_calldata",
            ],
        )
        def test_parse_cairo_call_should_succeed(
            self,
            cairo_run,
            address,
            selector,
            calldata_len_offset,
            calldata_len,
            calldata,
            expected_results,
        ):
            evm_encoded_call = (
                bytes.fromhex(address + selector + calldata_len_offset + calldata_len)
                + calldata
            )
            (
                is_err,
                to_addr,
                selector,
                calldata_len,
                returned_calldata,
                next_call_offset,
            ) = cairo_run("test__parse_cairo_call", evm_encoded_call=evm_encoded_call)

            (
                expected_is_err,
                expected_to_addr,
                expected_selector,
                expected_calldata_len,
                expected_returned_calldata,
                expected_next_call_offset,
            ) = expected_results

            assert is_err == expected_is_err
            assert to_addr == expected_to_addr
            assert selector == expected_selector
            assert calldata_len == expected_calldata_len
            assert returned_calldata == expected_returned_calldata
            assert next_call_offset == expected_next_call_offset
