from asyncio import run
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet


class TestArithmeticOperations(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_arithmetic_operations = await cls.starknet.deploy(
                source="./tests/cairo_files/instructions/test_arithmetic_operations.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_arithmetic_operations = await cls.starknet.deploy(
            source="./tests/cairo_files/instructions/test_arithmetic_operations.cairo",
            cairo_path=["src"],
            disable_hint_validation=True,
        )

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    async def test_everything_arithmetic(self):
        await self.test_arithmetic_operations.test__exec_add__should_add_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_mul__should_mul_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_sub__should_sub_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_div__should_div_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_sdiv__should_signed_div_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_mod__should_mod_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_smod__should_smod_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_addmod__should_add_0_and_1_and_div_rem_by_2().call()
        await self.test_arithmetic_operations.test__exec_mulmod__should_mul_0_and_1_and_div_rem_by_2().call()
        await self.test_arithmetic_operations.test__exec_exp__should_exp_0_and_1().call()
        await self.test_arithmetic_operations.test__exec_signextend__should_signextend_0_and_1().call()
