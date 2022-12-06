import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def duplication_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/instructions/test_duplication_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
class TestDupOperations:
    async def test__exec_dup1_should_duplicate_1st_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup1_should_duplicate_1st_item_to_top_of_stack().call()

    async def test__exec_dup2_should_duplicate_2nd_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup2_should_duplicate_2nd_item_to_top_of_stack().call()

    async def test__exec_dup3_should_duplicate_3rd_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup3_should_duplicate_3rd_item_to_top_of_stack().call()

    async def test__exec_dup4_should_duplicate_4th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup4_should_duplicate_4th_item_to_top_of_stack().call()

    async def test__exec_dup5_should_duplicate_5th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup5_should_duplicate_5th_item_to_top_of_stack().call()

    async def test__exec_dup6_should_duplicate_6th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup6_should_duplicate_6th_item_to_top_of_stack().call()

    async def test__exec_dup7_should_duplicate_7th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup7_should_duplicate_7th_item_to_top_of_stack().call()

    async def test__exec_dup8_should_duplicate_8th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup8_should_duplicate_8th_item_to_top_of_stack().call()

    async def test__exec_dup9_should_duplicate_9th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup9_should_duplicate_9th_item_to_top_of_stack().call()

    async def test__exec_dup10_should_duplicate_10th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup10_should_duplicate_10th_item_to_top_of_stack().call()

    async def test__exec_dup11_should_duplicate_11th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup11_should_duplicate_11th_item_to_top_of_stack().call()

    async def test__exec_dup12_should_duplicate_12th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup12_should_duplicate_12th_item_to_top_of_stack().call()

    async def test__exec_dup13_should_duplicate_13th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup13_should_duplicate_13th_item_to_top_of_stack().call()

    async def test__exec_dup14_should_duplicate_14th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup14_should_duplicate_14th_item_to_top_of_stack().call()

    async def test__exec_dup15_should_duplicate_15th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup15_should_duplicate_15th_item_to_top_of_stack().call()

    async def test__exec_dup16_should_duplicate_16th_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup16_should_duplicate_16th_item_to_top_of_stack().call()

    async def test__exec_dup_i_should_duplicate_ith_item_to_top_of_stack(
        self, duplication_operations
    ):
        await duplication_operations.test__exec_dup_i_should_duplicate_ith_item_to_top_of_stack().call()
