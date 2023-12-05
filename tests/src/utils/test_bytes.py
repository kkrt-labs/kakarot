import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture
async def bytes_(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/utils/test_bytes.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestBytes:
    class TestFeltToAscii:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF])
        async def test_should_return_ascii(self, bytes_, n):
            assert (
                str(n)
                == bytes(
                    (await bytes_.test__felt_to_ascii(n).call()).result.ascii
                ).decode()
            )

    class TestBytesToBytes8LittleEndian:
        @pytest.mark.parametrize("bytes_len", list(range(20)))
        async def test_should_return_bytes8(self, bytes_, bytes_len):
            bytes_array = list(range(bytes_len))
            bytes8_little_endian = [
                int(bytes(bytes_array[i : i + 8][::-1]).hex(), 16)
                for i in range(0, len(bytes_array), 8)
            ]
            assert (
                bytes8_little_endian
                == (
                    await bytes_.test__bytes_to_bytes8_little_endian(
                        list(range(bytes_len))
                    ).call()
                ).result.res
            )
