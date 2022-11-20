from asyncio import run
from unittest import IsolatedAsyncioTestCase

import pytest
from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet


class TestSystemOperations(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_system_operations = await cls.starknet.deploy(
                source="./tests/cairo_files/instructions/test_system_operations.cairo",
                cairo_path=["src"],
                disable_hint_validation=False,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_system_operations = await cls.starknet.deploy(
            source="./tests/cairo_files/instructions/test_system_operations.cairo",
            cairo_path=["src"],
            disable_hint_validation=False,
        )

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    @pytest.mark.xfail(strict=True)
    async def test_revert(self):
        await self.test_system_operations.test_exec_revert(reason=1000).call()
