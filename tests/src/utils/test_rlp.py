import pytest
from hypothesis import given
from hypothesis.strategies import binary
from rlp import codec, decode, encode

from tests.utils.constants import TRANSACTIONS
from tests.utils.helpers import rlp_encode_signed_data


class TestRLP:
    class TestDecodeType:
        @given(data=binary(min_size=0, max_size=255))
        def test_should_match_decoded_rlp_type_string(self, cairo_run, data):
            encoded_data = encode(data)

            [
                prefix,
                rlp_type,
                expected_len,
                expected_offset,
            ] = codec.consume_length_prefix(encoded_data, 0)
            expected_type = 0 if rlp_type == bytes else 1

            output = cairo_run("test__decode_type", data=list(encoded_data))

            assert output == [expected_type, expected_offset, expected_len]

        @given(data=binary(min_size=0, max_size=255))
        def test_should_match_decoded_rlp_type_list(self, cairo_run, data):
            encoded_data = encode([data])

            [
                prefix,
                rlp_type,
                expected_len,
                expected_offset,
            ] = codec.consume_length_prefix(encoded_data, 0)
            expected_type = 0 if rlp_type == bytes else 1

            output = cairo_run("test__decode_type", data=list(encoded_data))

            assert output == [expected_type, expected_offset, expected_len]

    class TestDecode:
        @given(data=binary(min_size=0, max_size=255))
        async def test_should_match_decode_reference_implementation(
            self, cairo_run, data
        ):
            encoded_data = encode(data)

            items_len, items = cairo_run("test__decode", data=list(encoded_data))
            decoded = items[0] if items_len == 1 else items
            assert decoded == decode(encoded_data)

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

            items_len, items = cairo_run("test__decode", data=list(rlp_encoding))
            decoded = items[0] if items_len == 1 else items
            assert decoded == decode(rlp_encoding)
