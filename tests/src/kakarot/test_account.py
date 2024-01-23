import pytest

from tests.utils.uint256 import int_to_uint256


@pytest.mark.asyncio
class TestAccount:
    class TestInit:
        @pytest.mark.parametrize(
            "address, code, nonce, balance",
            [(0, [], 0, 0), (2**160 - 1, [1, 2, 3], 1, 1)],
        )
        async def test_should_return_account_with_default_dict_as_storage(
            self, cairo_run, address, code, nonce, balance
        ):
            cairo_run(
                "test__init__should_return_account_with_default_dict_as_storage",
                evm_address=address,
                code=code,
                nonce=nonce,
                balance_low=balance,
            )

    class TestCopy:
        @pytest.mark.parametrize(
            "address, code, nonce, balance",
            [(0, [], 0, 0), (2**160 - 1, [1, 2, 3], 1, 1)],
        )
        async def test_should_return_new_account_with_same_attributes(
            self, cairo_run, address, code, nonce, balance
        ):
            cairo_run(
                "test__copy__should_return_new_account_with_same_attributes",
                evm_address=address,
                code=code,
                nonce=nonce,
                balance_low=balance,
            )

    class TestWriteStorage:
        @pytest.mark.parametrize("key, value", [(0, 0), (2**256 - 1, 2**256 - 1)])
        async def test_should_store_value_at_key(self, cairo_run, key, value):
            cairo_run(
                "test__write_storage__should_store_value_at_key",
                key=int_to_uint256(key),
                value=int_to_uint256(value),
            )

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
            self, cairo_run, nonce, code, expected_result
        ):
            output = cairo_run("test__has_code_or_nonce", nonce=nonce, code=code)
            assert output[0] == expected_result
