import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def push_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/units/kakarot/instructions/test_push_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
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

    async def test__exec_push16_should_add_16_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push16_should_add_16_byte_to_stack().call()

    async def test__exec_push17_should_add_17_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push17_should_add_17_byte_to_stack().call()

    async def test__exec_push18_should_add_18_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push18_should_add_18_byte_to_stack().call()

    async def test__exec_push19_should_add_19_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push19_should_add_19_byte_to_stack().call()

    async def test__exec_push20_should_add_20_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push20_should_add_20_byte_to_stack().call()

    async def test__exec_push21_should_add_21_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push21_should_add_21_byte_to_stack().call()

    async def test__exec_push22_should_add_22_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push22_should_add_22_byte_to_stack().call()

    async def test__exec_push23_should_add_23_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push23_should_add_23_byte_to_stack().call()

    async def test__exec_push24_should_add_24_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push24_should_add_24_byte_to_stack().call()

    async def test__exec_push25_should_add_25_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push25_should_add_25_byte_to_stack().call()

    async def test__exec_push26_should_add_26_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push26_should_add_26_byte_to_stack().call()

    async def test__exec_push27_should_add_27_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push27_should_add_27_byte_to_stack().call()

    async def test__exec_push28_should_add_28_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push28_should_add_28_byte_to_stack().call()

    async def test__exec_push29_should_add_29_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push29_should_add_29_byte_to_stack().call()

    async def test__exec_push30_should_add_30_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push30_should_add_30_byte_to_stack().call()

    async def test__exec_push31_should_add_31_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push31_should_add_31_byte_to_stack().call()

    async def test__exec_push32_should_add_32_byte_to_stack(self, push_operations):
        await push_operations.test__exec_push32_should_add_32_byte_to_stack().call()
