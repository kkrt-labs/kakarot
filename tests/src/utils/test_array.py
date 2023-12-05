import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture
async def array_(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/utils/test_array.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestArray:
    class TestReverse:
        @pytest.mark.parametrize(
            "arr",
            [
                [0, 1, 2, 3, 4],
                [0, 1, 2, 3],
                [0, 1, 2],
                [0, 1],
                [0],
                [],
            ],
        )
        async def test_should_return_reversed_array(self, array_, arr):
            assert arr[::-1] == ((await array_.test__reverse(arr).call()).result.rev)

    class TestCountNotZero:
        @pytest.mark.parametrize(
            "arr",
            [
                [0, 1, 0, 0, 4],
                [0, 1, 0, 3],
                [0, 1, 0],
                [0, 1],
                [0],
                [],
            ],
        )
        async def test_should_return_count_of_non_zero_elements(self, array_, arr):
            assert len(arr) - arr.count(0) == (
                (await array_.test__count_not_zero(arr).call()).result.count
            )

    class TestSlice:
        @pytest.mark.parametrize(
            "offset",
            [0, 1, 2, 3, 4, 5, 6],
        )
        @pytest.mark.parametrize(
            "size",
            [0, 1, 2, 3, 4, 5, 6],
        )
        async def test_should_return_slice(self, array_, offset, size):
            arr = [0, 1, 2, 3, 4]
            assert (arr + (offset + size) * [0])[offset : offset + size] == (
                (await array_.test__slice(arr, offset, size).call()).result.slice
            )
