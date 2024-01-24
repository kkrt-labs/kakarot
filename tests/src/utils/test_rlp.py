import random

import pytest
from rlp import codec, decode, encode

from tests.utils.constants import TRANSACTIONS
from tests.utils.helpers import rlp_encode_signed_data


class TestRLP:
    class TestDecodeType:
        @pytest.mark.parametrize(
            "payload_len",
            [0, 55, 256],
        )
        def test_should_match_decoded_rlp_type_string(self, cairo_run, payload_len):
            random.seed(0)
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
            type = expected_type
            offset = output[1]
            len = output[2]

            assert type == expected_type
            assert offset == expected_offset
            assert len == expected_len

        @pytest.mark.parametrize("payload_len", [0, 55, 256])
        def test_should_match_decoded_rlp_type_list(self, cairo_run, payload_len):
            random.seed(0)
            data = [random.randbytes(payload_len)]
            encoded_data = encode(data)

            [
                prefix,
                rlp_type,
                expected_len,
                expected_offset,
            ] = codec.consume_length_prefix(encoded_data, 0)
            expected_type = 1 if rlp_type == list else 0
            # print the instance of type

            # expected_type = 1 if rlp_type is a list class
            expected_type = 1 if rlp_type == list else 0

            output = cairo_run("test__decode_type", data=encoded_data)
            type = output[0]
            offset = output[1]
            len = output[2]

            assert type == expected_type
            assert offset == expected_offset
            assert len == expected_len

    class TestDecode:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_decode_reference_implementation(
            self, cairo_run, payload_len
        ):
            random.seed(0)
            data = [random.randbytes(payload_len - 1)]
            encoded_data = encode(data)
            expected_result = decode(encoded_data)

            # flatten the decoded data into a single bytes l
            # there must be no nested lists at the end
            flattened_data = flatten_and_concatenate(expected_result)
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
            flattened_data = flatten_and_concatenate(decoded_tx)
            flattened_output = cairo_run(
                "test__decode_transaction", data=rlp_encoding, is_list=1
            )

            assert flattened_data == flattened_output


def flatten_and_concatenate(data):
    result = []

    def flatten(item):
        if isinstance(item, list):
            for sub_item in item:
                flatten(sub_item)
        else:
            result.extend(item)

    flatten(data)
    return result
