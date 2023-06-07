import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def arithmetic_operations(starknet: Starknet):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_stop_and_arithmetic_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestArithmeticOperations:
    async def test__exec_add__should_add_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_add__should_add_0_and_1().call()

    async def test__exec_mul__should_mul_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_mul__should_mul_0_and_1().call()

    async def test__exec_sub__should_sub_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_sub__should_sub_0_and_1().call()

    async def test__exec_div__should_div_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_div__should_div_0_and_1().call()

    async def test__exec_sdiv__should_signed_div_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_sdiv__should_signed_div_0_and_1().call()

    async def test__exec_mod__should_mod_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_mod__should_mod_0_and_1().call()

    async def test__exec_smod__should_smod_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_smod__should_smod_0_and_1().call()

    async def test__exec_addmod__should_add_0_and_1_and_div_rem_by_2(
        self, arithmetic_operations
    ):
        await arithmetic_operations.test__exec_addmod__should_add_0_and_1_and_div_rem_by_2().call()

    async def test__exec_mulmod__should_mul_0_and_1_and_div_rem_by_2(
        self, arithmetic_operations
    ):
        await arithmetic_operations.test__exec_mulmod__should_mul_0_and_1_and_div_rem_by_2().call()

    async def test__exec_exp__should_exp_0_and_1(self, arithmetic_operations):
        await arithmetic_operations.test__exec_exp__should_exp_0_and_1().call()

    async def test__exec_signextend__should_signextend_0_and_1(
        self, arithmetic_operations
    ):
        await arithmetic_operations.test__exec_signextend__should_signextend_0_and_1().call()

    async def test__exec_stop(self, arithmetic_operations):
        await arithmetic_operations.test__exec_stop().call()
