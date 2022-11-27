import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def push_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/cairo_files/instructions/test_push_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
class TestPushOperations:
    async def test__exec_push1_should_add_1_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push1_should_add_1_byte_to_stack().call()

    async def test__exec_push2_should_add_2_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push2_should_add_2_byte_to_stack().call()

    async def test__exec_push3_should_add_3_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push3_should_add_3_byte_to_stack().call()

    async def test__exec_push4_should_add_4_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push4_should_add_4_byte_to_stack().call()

    async def test__exec_push5_should_add_5_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push5_should_add_5_byte_to_stack().call()

    async def test__exec_push6_should_add_6_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push6_should_add_6_byte_to_stack().call()

    async def test__exec_push7_should_add_7_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push7_should_add_7_byte_to_stack().call()

    async def test__exec_push8_should_add_8_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push8_should_add_8_byte_to_stack().call()

    async def test__exec_push9_should_add_9_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push9_should_add_9_byte_to_stack().call()

    async def test__exec_push10_should_add_10_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push10_should_add_10_byte_to_stack().call()

    async def test__exec_push11_should_add_11_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push11_should_add_11_byte_to_stack().call()

    async def test__exec_push12_should_add_12_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push12_should_add_12_byte_to_stack().call()

    async def test__exec_push13_should_add_13_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push13_should_add_13_byte_to_stack().call()

    async def test__exec_push14_should_add_14_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push14_should_add_14_byte_to_stack().call()

    async def test__exec_push15_should_add_15_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push15_should_add_15_byte_to_stack().call()
