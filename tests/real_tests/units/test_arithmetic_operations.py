from unittest import IsolatedAsyncioTestCase
from asyncio import run
from starkware.starknet.testing.starknet import Starknet
from cairo_coverage import cairo_coverage


class TestBasic(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.unit_test = await cls.starknet.deploy(
                source="./tests/units/kakarot/instructions/test_arithmetic_operations.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
            )

        run(_setUpClass(cls))

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    async def test_everything(self):
        await self.unit_test.test__add__should_add_0_and_1().call()
        await self.unit_test.test__mul__should_mul_0_and_1().call()
        await self.unit_test.test__sub__should_sub_0_and_1().call()
        await self.unit_test.test__div__should_div_0_and_1().call()
        await self.unit_test.test__sdiv__should_signed_div_0_and_1().call()
        await self.unit_test.test__mod__should_mod_0_and_1().call()
        await self.unit_test.test__smod__should_smod_0_and_1().call()
        await self.unit_test.test__addmod__should_add_0_and_1_and_div_rem_by_2().call()
        await self.unit_test.test__mulmod__should_mul_0_and_1_and_div_rem_by_2().call()
        await self.unit_test.test__signextend__should_signextend_0_and_1().call()
