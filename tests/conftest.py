import logging

logging.getLogger("asyncio").setLevel(logging.ERROR)
logger = logging.getLogger()


def pytest_addoption(parser):
    parser.addoption(
        "--profile-cairo",
        action="store_true",
        default=False,
        help="compute and dump TracerData for the VM runner: True or False",
    )


pytest_plugins = ["tests.fixtures.starknet"]
