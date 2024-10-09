# %% Imports
import logging
import multiprocessing as mp
from datetime import datetime

from kakarot_scripts.constants import COMPILED_CONTRACTS, DECLARED_CONTRACTS, NETWORK
from kakarot_scripts.utils.starknet import (
    compile_contract,
    compute_deployed_class_hash,
    dump_class_hashes,
)

mp.set_start_method("fork")

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
def main():
    # %% Compile
    logger.info(f"ℹ️  Compiling contracts for network {NETWORK['name']}")
    initial_time = datetime.now()
    with mp.Pool() as pool:
        pool.map(compile_contract, COMPILED_CONTRACTS)
    logger.info("ℹ️  Computing deployed class hashes")
    with mp.Pool() as pool:
        class_hashes = pool.map(compute_deployed_class_hash, DECLARED_CONTRACTS)
    dump_class_hashes(dict(zip(DECLARED_CONTRACTS, class_hashes)))

    logger.info(
        f"✅ Compiled all in {(datetime.now() - initial_time).total_seconds():.2f}s"
    )


# %% Run
if __name__ == "__main__":
    main()
