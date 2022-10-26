from tests import test_basic
from tests.units import test_memory, test_stack, test_execution_context
from tests.units.instructions import (
    test_arithmetic_operations,
    test_block_information,
    test_memory_operations,
)
from asyncio import run
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from cairo_coverage import cairo_coverage


class Coverage(
    test_basic.TestBasic,
    test_memory.TestMemory,
    test_stack.TestStack,
    test_execution_context.TestExecutionContext,
    test_arithmetic_operations.TestArithmeticOperations,
    test_block_information.TestBlockInformation,
    test_memory_operations.TestMemoryOperations,
):
    @classmethod
    def setUpClass(cls) -> None:
        async def setUpClass_(cls):
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            await test_basic.TestBasic.coverageSetupClass(cls)
            await test_memory.TestMemory.coverageSetupClass(cls)
            await test_stack.TestStack.coverageSetupClass(cls)
            await test_execution_context.TestExecutionContext.coverageSetupClass(cls)
            await test_arithmetic_operations.TestArithmeticOperations.coverageSetupClass(cls)
            await test_block_information.TestBlockInformation.coverageSetupClass(cls)
            await test_memory_operations.TestMemoryOperations.coverageSetupClass(cls)

        run(setUpClass_(cls))

    @classmethod
    def tearDownClass(cls):
        files: cairo_coverage.CoverageFile = cairo_coverage.report_runs(
            excluded_file={"site-packages", "cairo_files"}
        )
        total_covered = []
        for file in files:
            if file.pct_covered < 80:
                print(f"WARNING: {file.name} only {file.pct_covered:.2f}% covered")
            total_covered.append(file.pct_covered)
        if (val := not sum(total_covered) / len(files)) >= 80:
            print(f"WARNING: Project is not covered enough {val:.2f})")
