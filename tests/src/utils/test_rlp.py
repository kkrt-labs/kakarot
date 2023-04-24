import random

import pytest
import pytest_asyncio
from rlp import decode, encode


@pytest_asyncio.fixture
async def rlp(starknet):
    return await starknet.deploy(
        source="./tests/src/utils/test_rlp.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
class TestRLP:
    class TestEncodeList:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_encode_reference_implementation(
            self, rlp, payload_len
        ):

            random.seed(0)
            # data_len <= 55 is encoded as (0x80 + data_len), data, so payload_len - 1 is data_len
            data = random.randbytes(payload_len - 1)
            expected_result = encode([data])
            payload = encode(data)
            output = bytes(
                (await rlp.test__encode_list(list(payload)).call()).result.data
            )
            assert expected_result == output

    class TestDecode:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_decode_reference_implementation(
            self, rlp, payload_len
        ):
            random.seed(0)
            data = [random.randbytes(payload_len - 1)]
            encoded_data = encode(data)
            expected_result = decode(encoded_data)
            output = (
                await rlp.test__decode_at_index(list(encoded_data), 0).call()
            ).result
            assert output.is_list
            output = (
                await rlp.test__decode_at_index(list(output.data), 0).call()
            ).result
            assert not output.is_list
            assert expected_result == [bytes(output.data)]
