import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture
async def account(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestAccount:
    class TestInit:
        @pytest.mark.parametrize(
            "address, code, nonce, balance",
            [(0, [], 0, 0), (2**160 - 1, [1, 2, 3], 1, 1)],
        )
        async def test_should_return_account_with_default_dict_as_storage(
            self, account, address, code, nonce, balance
        ):
            await account.test__init__should_return_account_with_default_dict_as_storage(
                address, code, nonce, balance
            ).call()

    class TestCopy:
        @pytest.mark.parametrize(
            "address, code, nonce, balance",
            [(0, [], 0, 0), (2**160 - 1, [1, 2, 3], 1, 1)],
        )
        async def test_should_return_new_account_with_same_attributes(
            self, account, address, code, nonce, balance
        ):
            await account.test__copy__should_return_new_account_with_same_attributes(
                address, code, nonce, balance
            ).call()

    class TestWriteStorage:
        @pytest.mark.parametrize("key, value", [(0, 0), (2**256 - 1, 2**256 - 1)])
        async def test_should_store_value_at_key(self, account, key, value):
            await account.test__write_storage__should_store_value_at_key(
                int_to_uint256(key), int_to_uint256(value)
            ).call()

    class TestHasCodeOrNonce:
        @pytest.mark.parametrize(
            "nonce,code,expected_result",
            (
                (0, [], False),
                (1, [], True),
                (0, [1], True),
                (1, [1], True),
            ),
        )
        async def test_should_return_true_when_nonce(
            self, account, nonce, code, expected_result
        ):
            result = (
                await account.test__has_code_or_nonce(nonce, code).call()
            ).result.has_code_or_nonce
            assert result == expected_result
