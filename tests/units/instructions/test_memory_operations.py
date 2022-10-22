from unittest import IsolatedAsyncioTestCase
from asyncio import run
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet
from cairo_coverage import cairo_coverage


class TestBasic(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.unit_test = await cls.starknet.deploy(
                source="./tests/cairo_files/instructions/test_memory_operations.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
            )

        run(_setUpClass(cls))

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    async def test_everything(self):
        # aliexpress fuzzing
        [
            await self.unit_test.test__exec_pc__should_update_after_incrementing(
                increment=x
            ).call()
            for x in range(15)
        ]
