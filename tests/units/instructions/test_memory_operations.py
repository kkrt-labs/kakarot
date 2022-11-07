from asyncio import run
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet


class TestMemoryOperations(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_memory_operations = await cls.starknet.deploy(
                source="./tests/cairo_files/instructions/test_memory_operations.cairo",
                cairo_path=["src"],
                disable_hint_validation=False,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_memory_operations = await cls.starknet.deploy(
            source="./tests/cairo_files/instructions/test_memory_operations.cairo",
            cairo_path=["src"],
            disable_hint_validation=False,
        )

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    async def test_everything_memory(self):
        # aliexpress fuzzing
        [
            await self.test_memory_operations.test__exec_pc__should_update_after_incrementing(
                increment=x
            ).call()
            for x in range(1, 15)
        ]
        await self.test_memory_operations.test__exec_pop_should_pop_an_item_from_execution_context().call()
        await self.test_memory_operations.test__exec_mload_should_load_a_value_from_memory().call()
        await self.test_memory_operations.test__exec_mload_should_load_a_value_from_memory_with_memory_expansion().call()
        await self.test_memory_operations.test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize().call()
        await self.test_memory_operations.test__exec_gas_should_return_remaining_gas().call()
