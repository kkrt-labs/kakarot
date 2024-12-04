# %% Imports
import logging
import multiprocessing as mp
import re
from datetime import datetime

from kakarot_scripts.constants import (
    CAIRO_DIR,
    COMPILED_CONTRACTS,
    CONTRACTS,
    DECLARED_CONTRACTS,
    NETWORK,
)
from kakarot_scripts.utils.starknet import (
    compile_cairo_zero_contract,
    compile_scarb_package,
    compute_deployed_class_hash,
    dump_class_hashes,
    locate_scarb_root,
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

    # Split contracts into Cairo 0 and Cairo 1 to avoid
    # re-compiling the same package multiple times.
    cairo0_contracts = []
    cairo1_packages = set()

    for contract in COMPILED_CONTRACTS:
        contract_path = CONTRACTS.get(contract["contract_name"]) or CONTRACTS.get(
            re.sub("(?!^)([A-Z]+)", r"_\1", contract["contract_name"]).lower()
        )
        if contract_path.is_relative_to(CAIRO_DIR):
            cairo1_packages.add(locate_scarb_root(contract_path))
        else:
            cairo0_contracts.append(contract)

    with mp.Pool() as pool:
        cairo0_task = pool.map_async(compile_cairo_zero_contract, cairo0_contracts)
        cairo1_task = pool.map_async(compile_scarb_package, cairo1_packages)

        try:
            cairo0_task.wait()
            cairo1_task.wait()
            cairo0_task.get()
            cairo1_task.get()
        except Exception as e:
            logger.error(e)
            raise
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
