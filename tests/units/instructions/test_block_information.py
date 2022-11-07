from asyncio import run
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet


class TestBlockInformation(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_block_informations = await cls.starknet.deploy(
                source="./tests/cairo_files/instructions/test_block_information.cairo",
                cairo_path=["src"],
                disable_hint_validation=False,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_block_informations = await cls.starknet.deploy(
            source="./tests/cairo_files/instructions/test_block_information.cairo",
            cairo_path=["src"],
            disable_hint_validation=False,
        )

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    async def test_everything_block(self):
        await self.test_block_informations.test__chainId__should_push_chain_id_to_stack().call()
        await self.test_block_informations.test__coinbase_should_push_coinbase_address_to_stack().call()
        await self.test_block_informations.test__timestamp_should_push_block_timestamp_to_stack().call()
        await self.test_block_informations.test__number_should_push_block_number_to_stack().call()
        await self.test_block_informations.test__gaslimit_should_push_gaslimit_to_stack().call()
        await self.test_block_informations.test__difficulty_should_push_difficulty_to_stack().call()
        await self.test_block_informations.test__basefee_should_push_basefee_to_stack().call()
