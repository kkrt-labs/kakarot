import logging
from asyncio import run
from datetime import datetime

from starknet_py.compile.compiler import Compiler

from scripts.constants import COMPILED_CONTRACTS, CONTRACTS, SOURCE_DIR
from scripts.utils.starknet import dump_artifacts

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


async def main():
    logger.info(f"ℹ️  Compiling contracts")

    artifacts = {}
    for contract in COMPILED_CONTRACTS:
        logger.info(f"⏳ Compiling {contract}")
        start = datetime.now()
        artifacts[contract] = Compiler(
            contract_source=CONTRACTS[contract["contract_name"]].read_text(),
            is_account_contract=contract["is_account_contract"],
            cairo_path=[str(SOURCE_DIR)],
        ).compile_contract()
        elapsed = datetime.now() - start
        logger.info(f"✅ Compiled in {elapsed.total_seconds()}s")

    dump_artifacts(artifacts)


if __name__ == "__main__":
    run(main())
