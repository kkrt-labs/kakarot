import random

import pytest
from rlp import codec, decode, encode

from tests.utils.constants import TRANSACTIONS
from tests.utils.helpers import flatten, rlp_encode_signed_data


class TestRLP:
    class TestDecodeType:
        @pytest.mark.parametrize(
            "payload_len",
            [0, 55, 256],
        )
        def test_should_match_decoded_rlp_type_string(self, cairo_run, payload_len):
            # generate random string of bytes. if payload_len is 0, then generate a single byte inferior to 0x80
            data = (
                random.randbytes(payload_len)
                if payload_len != 0
                else random.randint(0, 0x80)
            )
            encoded_data = encode(data)

            [
                prefix,
                rlp_type,
                expected_len,
                expected_offset,
            ] = codec.consume_length_prefix(encoded_data, 0)
            expected_type = 0 if rlp_type == bytes else 1

            output = cairo_run("test__decode_type", data=encoded_data)

            assert output[0] == expected_type
            assert output[1] == expected_offset
            assert output[2] == expected_len

        @pytest.mark.parametrize("payload_len", [0, 55, 256])
        def test_should_match_decoded_rlp_type_list(self, cairo_run, payload_len):
            data = [random.randbytes(payload_len)]
            encoded_data = encode(data)

            [
                prefix,
                rlp_type,
                expected_len,
                expected_offset,
            ] = codec.consume_length_prefix(encoded_data, 0)
            expected_type = 1 if rlp_type == list else 0

            output = cairo_run("test__decode_type", data=encoded_data)

            assert output[0] == expected_type
            assert output[1] == expected_offset
            assert output[2] == expected_len

    class TestDecode:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_decode_reference_implementation(
            self, cairo_run, payload_len
        ):
            data = [random.randbytes(payload_len - 1)]
            encoded_data = encode(data)
            expected_result = decode(encoded_data)

            # flatten the decoded data into a single bytes l
            # there must be no nested lists at the end
            flattened_data = flatten(list(expected_result))
            flattened_output = cairo_run(
                "test__decode", data=list(encoded_data), is_list=1
            )

            assert flattened_data == flattened_output

        @pytest.mark.parametrize("transaction", TRANSACTIONS)
        def test_should_decode_all_tx_types(self, cairo_run, transaction):
            transaction = {**transaction, "chainId": 1}
            encoded_unsigned_tx = rlp_encode_signed_data(transaction)
            if "type" in transaction:
                # remove the type info from the encoded RLP
                # create bytearray from bytes list and remove the first byte
                rlp_encoding = bytes(encoded_unsigned_tx[1:])
            else:
                rlp_encoding = encoded_unsigned_tx

            decoded_tx = decode(rlp_encoding)

            # flatten the decoded data into a single bytes l
            # there must be no nested lists at the end
            flattened_data = flatten(decoded_tx)
            flattened_output = cairo_run(
                "test__decode_transaction", data=rlp_encoding, is_list=1
            )

            assert flattened_data == flattened_output
