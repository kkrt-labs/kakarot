import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.uint256 import int_to_uint256

PRIME = 0x800000000000011000000000000000000000000000000000000000000000001


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

    class TestFeltToBytesLittle:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        async def test_should_return_bytes(self, bytes_, n):
            res = bytes(
                (await bytes_.test__felt_to_bytes_little(n).call()).result.bytes
            )
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0"))[::-1] == res

    class TestFeltToBytes:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        async def test_should_return_bytes(self, bytes_, n):
            res = bytes((await bytes_.test__felt_to_bytes(n).call()).result.bytes)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0")) == res

    class TestFeltToBytes20:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        async def test_should_return_bytes20(self, bytes_, n):
            res = bytes((await bytes_.test__felt_to_bytes20(n).call()).result.bytes)
            assert f"{n:064x}"[-40:] == res.hex()

    class TestUint256ToBytesLittle:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        async def test_should_return_bytes(self, bytes_, n):
            res = bytes(
                (
                    await bytes_.test__uint256_to_bytes_little(int_to_uint256(n)).call()
                ).result.bytes
            )
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0"))[::-1] == res

    class TestUint256ToBytes:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        async def test_should_return_bytes(self, bytes_, n):
            res = bytes(
                (
                    await bytes_.test__uint256_to_bytes(int_to_uint256(n)).call()
                ).result.bytes
            )
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0")) == res

    class TestUint256ToBytes32:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        async def test_should_return_bytes(self, bytes_, n):
            res = bytes(
                (
                    await bytes_.test__uint256_to_bytes32(int_to_uint256(n)).call()
                ).result.bytes
            )
            assert bytes.fromhex(f"{n:064x}") == res
