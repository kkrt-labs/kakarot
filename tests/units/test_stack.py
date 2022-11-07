from asyncio import run
from contextlib import contextmanager
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException


class TestStack(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_stack = await cls.starknet.deploy(
                source="./tests/cairo_files/test_stack.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_stack = await cls.starknet.deploy(
            source="./tests/cairo_files/test_stack.cairo",
            cairo_path=["src"],
            disable_hint_validation=True,
        )

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

    async def test_everything_stack(self):
        await self.test_stack.test__init__should_return_an_empty_stack().call()
        await self.test_stack.test__len__should_return_the_length_of_the_stack().call()
        await self.test_stack.test__push__should_add_an_element_to_the_stack().call()
        await self.test_stack.test__pop__should_pop_an_element_to_the_stack().call()
        await self.test_stack.test__pop__should_pop_N_elements_to_the_stack().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.test_stack.test__pop__should_fail__when_stack_underflow_pop().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.test_stack.test__pop__should_fail__when_stack_underflow_pop_n().call()

        await self.test_stack.test__peek__should_return_stack_at_given_index__when_value_is_0().call()
        await self.test_stack.test__peek__should_return_stack_at_given_index__when_value_is_1().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.test_stack.test__peek__should_fail_when_underflow().call()

        await self.test_stack.test__swap__should_swap_2_stacks().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.test_stack.test__swap__should_fail__when_index_1_is_underflow().call()

        with self.raisesStarknetError("Kakarot: StackUnderflow"):
            await self.test_stack.test__swap__should_fail__when_index_2_is_underflow().call()
