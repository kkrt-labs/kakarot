import random

import pytest
import pytest_asyncio
from rlp import Serializable, decode, encode
from rlp.sedes import big_endian_int, binary

from tests.utils.errors import kakarot_error

random.seed(0)


@pytest_asyncio.fixture
async def rlp(starknet):
    return await starknet.deploy(
        source="./tests/unit/src/utils/test_rlp.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.fixture
def legacy_tx():
    class LegacyTx(Serializable):
        fields = [
            ("nonce", big_endian_int),
            ("gas_price", big_endian_int),
            ("gas", big_endian_int),
            ("to", binary),
            ("value", big_endian_int),
            ("data", binary),
            ("v", big_endian_int),
            ("r", binary),
            ("s", binary),
        ]

    def _factory(i=0):
        random.seed(i)
        return LegacyTx(
            nonce=random.randint(0, 10_000),
            gas_price=random.randint(0, 10_000),
            gas=random.randint(0, 10_000),
            to=random.randbytes(20),
            value=random.randint(0, 10_000),
            data=random.randbytes(32),
            v=random.randint(0, 10_000),
            r=random.randbytes(32),
            s=random.randbytes(32),
        )

    return _factory


@pytest.fixture
def eip1559_tx():
    class EIP1559Tx(Serializable):
        fields = [
            ("chain_id", big_endian_int),
            ("nonce", big_endian_int),
            ("max_priority_fee_per_gas", big_endian_int),
            ("max_fee_per_gas", big_endian_int),
            ("gas", big_endian_int),
            ("to", binary),
            ("value", big_endian_int),
            ("data", binary),
            ("access_list", binary),
            ("v", big_endian_int),
            ("r", binary),
            ("s", binary),
        ]

    def _factory(i=0):
        random.seed(i)
        return EIP1559Tx(
            chain_id=random.randint(0, 10_000),
            nonce=random.randint(0, 10_000),
            max_priority_fee_per_gas=random.randint(0, 10_000),
            max_fee_per_gas=random.randint(0, 10_000),
            gas=random.randint(0, 10_000),
            to=random.randbytes(20),
            value=random.randint(0, 10_000),
            data=random.randbytes(32),
            access_list=random.randbytes(32),
            v=random.randint(0, 10_000),
            r=random.randbytes(32),
            s=random.randbytes(32),
        )

    return _factory


@pytest.fixture
def tx_fixture(legacy_tx, eip1559_tx):
    def _factory(tx_type, i=0):
        if tx_type == 2:
            return eip1559_tx(i)
        return legacy_tx(i)

    return _factory


@pytest.mark.asyncio
class TestRLP:
    class TestEncodeList:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_encode_reference_implementation(
            self, rlp, payload_len
        ):
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

        @pytest.mark.parametrize("tx_type", [1, 2])
        async def test_should_decode_tx(self, rlp, tx_fixture, tx_type):
            tx = tx_fixture(tx_type)
            encoded_tx = encode(tx)
            expected_result = decode(encoded_tx)

            output = (
                await rlp.test__decode_at_index(list(encoded_tx), 0).call()
            ).result
            assert output.is_list == True
            for i in range(len(tx)):
                assert expected_result[i] == bytes(
                    (await rlp.test__decode_at_index(output.data, i).call()).result.data
                )
            with kakarot_error():
                # test that the output len is correct by raising out_of_bound for next index
                await rlp.test__decode_at_index(output.data, len(tx)).call()
