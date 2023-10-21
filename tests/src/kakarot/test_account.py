import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import cairo_error


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
            "address, code, nonce", [(0, [], 0), (2**160 - 1, [1, 2, 3], 1)]
        )
        async def test_should_return_account_with_default_dict_as_storage(
            self, account, address, code, nonce
        ):
            await account.test__init__should_return_account_with_default_dict_as_storage(
                address, code, nonce
            ).call()

    class TestCopy:
        @pytest.mark.parametrize(
            "address, code, nonce", [(0, [], 0), (2**160 - 1, [1, 2, 3], 1)]
        )
        async def test_should_return_account_with_default_dict_as_storage(
            self, account, address, code, nonce
        ):
            await account.test__copy__should_return_new_account_with_same_attributes(
                address, code, nonce
            ).call()

    class TestFinalize:
        @pytest.mark.parametrize(
            "address, code, nonce", [(0, [], 0), (2**160 - 1, [1, 2, 3], 1)]
        )
        async def test_should_return_summary(self, account, address, code, nonce):
            await account.test__finalize__should_return_summary(
                address, code, nonce
            ).call()

        @pytest.mark.parametrize(
            "address, code, nonce", [(0, [], 0), (2**160 - 1, [1, 2, 3], 1)]
        )
        async def test_should_return_summary_with_no_default_dict(
            self, account, address, code, nonce
        ):
            with cairo_error("KeyError"):
                await account.test__finalize__should_return_summary_with_no_default_dict(
                    address, code, nonce
                ).call()
