import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def environmental_information(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/cairo_files/instructions/test_environmental_information.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestBlockInformation:
    async def test_everything_environmental(self, environmental_information):
        await environmental_information.test__exec_address__should_push_address_to_stack().call()
        await environmental_information.test__exec_extcodecopy__().call()        
