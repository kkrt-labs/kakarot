from contextlib import contextmanager
from unittest import IsolatedAsyncioTestCase
from asyncio import run
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo

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
                source="./tests/cairo_files/test_memory.cairo",
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
        await self.unit_test.test__init__should_return_an_empty_memory().call()
        await self.unit_test.test__len__should_return_the_length_of_the_memory().call()
        await self.unit_test.test__store__should_add_an_element_to_the_memory().call()
        await self.unit_test.test__load__should_load_an_element_from_the_memory().call()

        with self.raisesStarknetError("Kakarot: MemoryOverflow"):
            await self.unit_test.test__load__should_fail__when_out_of_memory().call()

        await self.unit_test.test__dump__should_print_the_memory().call()
