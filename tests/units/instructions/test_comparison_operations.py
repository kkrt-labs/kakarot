from asyncio import run
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet


class TestComparisonOperations(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_comparison_operations = await cls.starknet.deploy(
                source="./tests/cairo_files/instructions/test_comparison_operations.cairo",
                cairo_path=["src"],
                disable_hint_validation=False,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_comparison_operations = await cls.starknet.deploy(
            source="./tests/cairo_files/instructions/test_comparison_operations.cairo",
            cairo_path=["src"],
            disable_hint_validation=False,
        )

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    async def test__exec_lt__should_pop_0_and_1_and_push_0__when_0_not_lt_1(self):
        await self.test_comparison_operations.test__exec_lt__should_pop_0_and_1_and_push_0__when_0_not_lt_1().call()

    async def test__exec_lt__should_pop_0_and_1_and_push_1__when_0_lt_1(self):
        await self.test_comparison_operations.test__exec_lt__should_pop_0_and_1_and_push_1__when_0_lt_1().call()

    async def test__exec_gt__should_pop_0_and_1_and_push_0__when_0_not_gt_1(self):
        await self.test_comparison_operations.test__exec_gt__should_pop_0_and_1_and_push_0__when_0_not_gt_1().call()

    async def test__exec_gt__should_pop_0_and_1_and_push_1__when_0_gt_1(self):
        await self.test_comparison_operations.test__exec_gt__should_pop_0_and_1_and_push_1__when_0_gt_1().call()

    async def test__exec_slt__should_pop_0_and_1_and_push_0__when_0_not_slt_1(self):
        await self.test_comparison_operations.test__exec_slt__should_pop_0_and_1_and_push_0__when_0_not_slt_1().call()

    async def test__exec_slt__should_pop_0_and_1_and_push_1__when_0_slt_1(self):
        await self.test_comparison_operations.test__exec_slt__should_pop_0_and_1_and_push_1__when_0_slt_1().call()

    async def test__exec_sgt__should_pop_0_and_1_and_push_0__when_0_not_sgt_1(self):
        await self.test_comparison_operations.test__exec_sgt__should_pop_0_and_1_and_push_0__when_0_not_sgt_1().call()

    async def test__exec_sgt__should_pop_0_and_1_and_push_1__when_0_sgt_1(self):
        await self.test_comparison_operations.test__exec_sgt__should_pop_0_and_1_and_push_1__when_0_sgt_1().call()

    async def test__exec_eq__should_pop_0_and_1_and_push_0__when_0_not_eq_1(self):
        await self.test_comparison_operations.test__exec_eq__should_pop_0_and_1_and_push_0__when_0_not_eq_1().call()

    async def test__exec_eq__should_pop_0_and_1_and_push_1__when_0_eq_1(self):
        await self.test_comparison_operations.test__exec_eq__should_pop_0_and_1_and_push_1__when_0_eq_1().call()

    async def test__exec_iszero__should_pop_0_and_push_0__when_0_is_not_zero(self):
        await self.test_comparison_operations.test__exec_iszero__should_pop_0_and_push_0__when_0_is_not_zero().call()

    async def test__exec_iszero__should_pop_0_and_push_1__when_0_is_zero(self):
        await self.test_comparison_operations.test__exec_iszero__should_pop_0_and_push_1__when_0_is_zero().call()

    async def test__exec_and__should_pop_0_and_1_and_push_0__when_0_and_1_are_not_true(
        self,
    ):
        await self.test_comparison_operations.test__exec_and__should_pop_0_and_1_and_push_0__when_0_and_1_are_not_true().call()

    async def test__exec_and__should_pop_0_and_1_and_push_1__when_0_and_1_are_true(
        self,
    ):
        await self.test_comparison_operations.test__exec_and__should_pop_0_and_1_and_push_1__when_0_and_1_are_true().call()

    async def test__exec_or__should_pop_0_and_1_and_push_0__when_0_or_1_are_not_true(
        self,
    ):
        await self.test_comparison_operations.test__exec_or__should_pop_0_and_1_and_push_0__when_0_or_1_are_not_true().call()

    async def test__exec_or__should_pop_0_and_1_and_push_1__when_0_or_1_are_true(self):
        await self.test_comparison_operations.test__exec_or__should_pop_0_and_1_and_push_1__when_0_or_1_are_true().call()

    async def test__exec_shl__should_pop_0_and_1_and_push_left_shift(self):
        await self.test_comparison_operations.test__exec_shl__should_pop_0_and_1_and_push_left_shift().call()

    async def test__exec_shr__should_pop_0_and_1_and_push_right_shift(self):
        await self.test_comparison_operations.test__exec_shr__should_pop_0_and_1_and_push_right_shift().call()

    async def test__exec_sar__should_pop_0_and_1_and_push_shr(self):
        await self.test_comparison_operations.test__exec_sar__should_pop_0_and_1_and_push_shr().call()
