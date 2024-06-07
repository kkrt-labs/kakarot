import pytest

from kakarot_scripts.utils.l1 import deploy_on_l1


@pytest.fixture(scope="session")
async def setup_l1_messaging():
    starknet_messaging_l1 = await deploy_on_l1(
        "L1L2Messaging", "StarknetMessagingLocal"
    )
    return starknet_messaging_l1


@pytest.fixture(scope="session")
async def setup_l2_messaging():
    # TODO: deploy a Cairo contract that receives messages to send from L2
    # using the Cairo precompiles calls
    pass
