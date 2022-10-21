from contextlib import contextmanager
from unittest import IsolatedAsyncioTestCase
from asyncio import run
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from cairo_coverage import cairo_coverage


class TestBasic(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.unit_test = await cls.starknet.deploy(
                source="./tests/real_tests/cairo_files/test_stack.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
            )

        run(_setUpClass(cls))

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    @contextmanager
    def raisesStarknetError(self, error_message):
        with self.assertRaises(StarkException) as error_msg:
            yield error_msg
        self.assertTrue(
            f"Error message: {error_message}" in str(error_msg.exception.message)
        )

    async def test_everything(self):
        await self.unit_test.test__init__should_return_an_empty_stack().call()
        await self.unit_test.test__len__should_return_the_length_of_the_stack().call()
        await self.unit_test.test__push__should_add_an_element_to_the_stack().call()
        await self.unit_test.test__pop__should_pop_an_element_to_the_stack().call()
        await self.unit_test.test__pop__should_pop_N_elements_to_the_stack().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.unit_test.test__pop__should_fail__when_stack_underflow_pop().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.unit_test.test__pop__should_fail__when_stack_underflow_pop_n().call()

        await self.unit_test.test__peek__should_return_stack_at_given_index__when_value_is_0().call()
        await self.unit_test.test__peek__should_return_stack_at_given_index__when_value_is_1().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.unit_test.test__peek__should_fail_when_underflow().call()

        await self.unit_test.test__swap__should_swap_2_stacks().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.unit_test.test__swap__should_fail__when_index_1_is_underflow().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.unit_test.test__swap__should_fail__when_index_2_is_underflow().call()

        await self.unit_test.test__dump__should_print_the_stack().call()
