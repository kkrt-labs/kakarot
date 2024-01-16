import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="session")
async def state(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/test_state.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestState:
    class TestInit:
        async def test_should_return_state_with_default_dicts(self, cairo_run):
            cairo_run("test__init__should_return_state_with_default_dicts")

    class TestCopy:
        async def test_should_return_new_state_with_same_attributes(self, state):
            await state.test__copy__should_return_new_state_with_same_attributes().call()

    class TestIsAccountAlive:
        @pytest.mark.parametrize(
            "nonce, code, balance_low, expected_result",
            (
                (0, [], 0, False),
                (1, [], 0, True),
                (0, [1], 0, True),
                (0, [], 1, True),
            ),
        )
        async def test_existing_account(
            self, state, nonce, code, balance_low, expected_result
        ):
            result = (
                await state.test__is_account_alive__existing_account(
                    nonce, code, balance_low
                ).call()
            ).result.is_alive
            assert result == expected_result

        async def test_not_in_state(self, cairo_run):
            cairo_run("test__is_account_alive__not_in_state")


@pytest.mark.asyncio
class TestInternals:
    class TestCopyAccounts:
        async def test_should_handle_null_pointers(self, state):
            await state.test___copy_accounts__should_handle_null_pointers().call()
