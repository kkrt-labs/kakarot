import re

import pytest
import pytest_asyncio


@pytest_asyncio.fixture
async def rlp(starknet):
    return await starknet.deploy(
        source="./tests/unit/src/utils/test_rlp.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.fixture
def data_to_list_long():
    return list(
        b"\x80\x85\x040\xe24\x00\x82R\x08\x94\xdcTM\x1a\xa8\x8f\xf8\xbb\xd2\xf2\xae\xc7T\xb1\xf1\xe9\x9e\x18\x12\xfd\x01\x80\x1b\xa0\x11\r\x8f\xee\x1d\xe5=\xf0\x87\x0en\xb5\x99\xed;\xf6\x8f\xb3\xf1\xe6,\x82\xdf\xe5\x97lF|\x97%;\x15\xa04P\xb7=*\xef \t\xf0&\xbc\xbf\tz%z\xe7\xa3~\xb5\xd3\xb7=\xc0v\n\xef\xad+\x98\xe3'"
    )


@pytest.fixture
def data_to_list_short():
    return list(
        bytes.fromhex(
            "80850430e2340082520801801ba0110d8fee1de53df0870e6eb599ed3bf68fb3f1e62c82dfe5976c467c97253b15"
        )
    )


@pytest.mark.asyncio
class TestRLP:
    async def test__encode_rlp_list_longer_55_bytes(self, rlp, data_to_list_long):
        rlp_list = await rlp.test_encode_rlp_list(data_to_list_long).execute()
        data_len = len(data_to_list_long)
        data_len_len = len(data_len.to_bytes((data_len.bit_length() + 7) // 8, "big"))
        prefix = 0xF7 + data_len_len
        expected_list = [
            prefix,
            *list(data_len.to_bytes((data_len.bit_length() + 7) // 8, "big")),
            *data_to_list_long,
        ]
        assert expected_list == rlp_list.result.data

    async def test__encode_rlp_list_smaller_55_bytes(self, rlp, data_to_list_short):
        rlp_list = await rlp.test_encode_rlp_list(data_to_list_short).execute()
        data_len = len(data_to_list_short)
        prefix = 0xC0 + data_len
        expected_list = [prefix, *data_to_list_short]
        assert expected_list == rlp_list.result.data
