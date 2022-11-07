from asyncio import run
from contextlib import contextmanager
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException


class TestMemory(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_memory = await cls.starknet.deploy(
                source="./tests/cairo_files/test_memory.cairo",
                cairo_path=["src"],
                disable_hint_validation=False,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_memory = await cls.starknet.deploy(
            source="./tests/cairo_files/test_memory.cairo",
            cairo_path=["src"],
            disable_hint_validation=False,
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

    async def test_everything_memory(self):
        await self.test_memory.test__init__should_return_an_empty_memory().call()
        await self.test_memory.test__len__should_return_the_length_of_the_memory().call()
        await self.test_memory.test__store__should_add_an_element_to_the_memory().call()
        await self.test_memory.test__load__should_load_an_element_from_the_memory().call()
        await self.test_memory.test__load__should_load_an_element_from_the_memory_with_offset(
            8, 2 * 256**8, 256**8
        ).call()
        await self.test_memory.test__load__should_load_an_element_from_the_memory_with_offset(
            7, 2 * 256**7, 256**7
        ).call()
        await self.test_memory.test__load__should_load_an_element_from_the_memory_with_offset(
            23, 3 * 256**7, 2 * 256**7
        ).call()
        await self.test_memory.test__load__should_load_an_element_from_the_memory_with_offset(
            33, 4 * 256**1, 3 * 256**1
        ).call()
        await self.test_memory.test__load__should_load_an_element_from_the_memory_with_offset(
            63, 0, 4 * 256**15
        ).call()
        await self.test_memory.test__load__should_load_an_element_from_the_memory_with_offset(
            500, 0, 0
        ).call()

        await self.test_memory.test__expand__should_return_the_same_memory_and_no_cost().call()
        await self.test_memory.test__expand__should_return_expanded_memory_and_cost().call()
        await self.test_memory.test__insure_length__should_return_the_same_memory_and_no_cost().call()
        await self.test_memory.test__insure_length__should_return_expanded_memory_and_cost().call()
