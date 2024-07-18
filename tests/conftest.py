import asyncio
import logging
import random

import pytest
from starkware.cairo.lang.instances import LAYOUTS

random.seed(0xABDE1)

logging.getLogger("asyncio").setLevel(logging.ERROR)
logger = logging.getLogger()


def pytest_addoption(parser):
    parser.addoption(
        "--profile-cairo",
        action="store_true",
        default=False,
        help="compute and dump TracerData for the VM runner: True or False",
    )
    parser.addoption(
        "--proof-mode",
        action="store_true",
        default=False,
        help="run the CairoRunner in proof mode: True or False",
    )
    parser.addoption(
        "--layout",
        choices=list(LAYOUTS.keys()),
        default="starknet_with_keccak",
        help="The layout of the Cairo AIR.",
    )


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop()
    yield loop
    loop.close()


pytest_plugins = ["tests.fixtures.starknet"]
