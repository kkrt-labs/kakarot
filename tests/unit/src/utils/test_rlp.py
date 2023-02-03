import os
from random import randint

import pytest
import pytest_asyncio
from rlp import decode


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


# using https://etherscan.io/getRawTx?tx= to get samples
def raw_tx_samples():
    return [
        bytes.fromhex(
            "f86e8263eb8505b4f9a92b82753094e688b84b23f322a994a53dbf8e15fa82cdb71127880c0e2d2235b8de888026a02c924804fba1a12e820afb1da9a2a9dd3d23894b908d11431eef22dd36e67ea0a072590d04f3e8846aabdddb6efe67a3881a27ab17d9d45fff60ef46a3bddd27f9"
        ),
        bytes.fromhex(
            "f871018302c89e808506a713e0da82520894e35bbafa0266089f95d745d348b468622805d82b876e00f6f06088e880c080a0081ba82131d62d76d2b836878d2b7949f2ce5de8387f685907226f505df95364a014d781beb05623e5e8836622bfb205127ddc9c398dd04c44a8ce1184cea9527b"
        ),
        bytes.fromhex(
            "f90135010a840adc656b8508d6c03c4a8303088e941111111254fb6c44bac0bed2854e76f90643097d80b8c82e95b6c800000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce000000000000000000000000000000000000000000006c36df1cfb2498bfc4fa000000000000000000000000000000000000000000000000000000000051a4a60000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000100000000000000003b6d0340773dd321873fe70553acc295b1b49a104d968cc80bd34b36c001a03ef4c950835e3402d10615a9ca96b9143921e378e80d8ceebd5b07710cb03657a028e3f573e7484eff9867045923e61e75d29f65b9af2fb82b7a57a163742eda70"
        ),
        bytes.fromhex(
            "f86f830216c58506676ef5ec826b6c941cedc0f3af8f9841b0a1f5c1a4ddc6e1a1629074880101009bbb1fb5aa8026a0044e77af97e063a12b87fbcc083eae2b4b8daeaac46f967b5dcc82cfa1725192a06a9626195a8430f83676b3c1ca8037bbf5d2108161b0aaf07968a2cd442dc8ef"
        ),
    ]


@pytest.mark.asyncio
class TestRLP:
    class TestRLPListEncode:
        async def test__encode_rlp_list_longer_55_bytes(self, rlp, data_to_list_long):
            rlp_list = await rlp.test__encode_list(data_to_list_long).call()
            data_len = len(data_to_list_long)
            data_len_len = len(
                data_len.to_bytes((data_len.bit_length() + 7) // 8, "big")
            )
            prefix = 0xF7 + data_len_len
            expected_list = [
                prefix,
                *list(data_len.to_bytes((data_len.bit_length() + 7) // 8, "big")),
                *data_to_list_long,
            ]
            assert expected_list == rlp_list.result.data

        async def test__encode_rlp_list_smaller_55_bytes(self, rlp, data_to_list_short):
            rlp_list = await rlp.test__encode_list(data_to_list_short).call()
            data_len = len(data_to_list_short)
            prefix = 0xC0 + data_len
            expected_list = [prefix, *data_to_list_short]
            assert expected_list == rlp_list.result.data

    class TestRLPDecode:
        async def test__decode_int_le_127(self, rlp):
            number = randint(0, 127)
            decoded = await rlp.test__rlp_decode_at_index([number], 0).call()
            assert decoded.result.data == [number]
            assert decoded.result.is_list == False

        async def test__decode_string_le_55(self, rlp):
            string = list(os.urandom(randint(2, 54)))
            prefix = 0x80 + len(string)
            decoded = await rlp.test__rlp_decode_at_index([prefix, *string], 0).call()
            assert decoded.result.data == string
            assert decoded.result.is_list == False

        async def test__decode_string_gt_55(self, rlp):
            data_len = randint(56, 100000)
            string = list(os.urandom(data_len))
            data_len = list(data_len.to_bytes((data_len.bit_length() + 7) // 8, "big"))
            data_len_len = len(data_len)
            prefix = 0xB7 + data_len_len
            decoded = await rlp.test__rlp_decode_at_index(
                [prefix, *data_len, *string], 0
            ).call()
            assert decoded.result.data == string
            assert decoded.result.is_list == False

        @pytest.mark.parametrize("raw_tx", raw_tx_samples())
        async def test__decode_list_le_55(self, rlp, raw_tx):
            contract_decoded = await rlp.test__rlp_decode_at_index(
                list(raw_tx), 0
            ).call()
            assert contract_decoded.result.is_list == True
            decoded = decode(raw_tx)
            for i in range(0, len(decoded)):
                sub_decoded = await rlp.test__rlp_decode_at_index(
                    contract_decoded.result.data, i
                ).call()
                assert list(decoded[i]) == sub_decoded.result.data
