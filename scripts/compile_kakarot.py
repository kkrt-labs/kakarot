# %% Imports
import logging
import subprocess
from asyncio import run
from datetime import datetime

from scripts.constants import (
    BUILD_DIR,
    COMPILED_CONTRACTS,
    CONTRACTS,
    NETWORK,
    SOURCE_DIR,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def compile_contract(contract):
    output = subprocess.run(
        [
            "starknet-compile-deprecated",
            CONTRACTS[contract["contract_name"]],
            "--output",
            BUILD_DIR / f"{contract['contract_name']}.json",
            "--cairo_path",
            str(SOURCE_DIR),
            *(["--account_contract"] if contract["is_account_contract"] else []),
            *(["--disable_hint_validation"] if NETWORK == "devnet" else []),
        ],
        capture_output=True,
    )
    if output.returncode != 0:
        raise RuntimeError(output.stderr)


# %% Main
async def main():
    # %% Compile
    logger.info(f"ℹ️  Compiling contracts for network {NETWORK}")
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
