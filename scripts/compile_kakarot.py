# %% Imports
import logging
from asyncio import run
from datetime import datetime

from scripts.constants import COMPILED_CONTRACTS, NETWORK
from scripts.utils.starknet import compile_contract

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Compile
    logger.info(f"ℹ️  Compiling contracts for network {NETWORK['name']}")
    initial_time = datetime.now()
    for contract in COMPILED_CONTRACTS:
        logger.info(f"⏳ Compiling {contract}")
        start = datetime.now()
        compile_contract(contract)
        elapsed = datetime.now() - start
        logger.info(f"✅ Compiled in {elapsed.total_seconds():.2f}s")

    logger.info(
        f"✅ Compiled all in {(datetime.now() - initial_time).total_seconds():.2f}s"
    )


# %% Run
if __name__ == "__main__":
    run(main())
