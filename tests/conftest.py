import asyncio
import logging

import pytest

logging.getLogger("asyncio").setLevel(logging.ERROR)
logger = logging.getLogger()


def pytest_addoption(parser):
    parser.addoption(
        "--profile-cairo",
        action="store_true",
        default=False,
        help="compute and dump TracerData for the VM runner: True or False",
    )


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop()
    yield loop
    loop.close()


pytest_plugins = ["tests.fixtures.starknet"]
