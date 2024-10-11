# %% Imports
from uvloop import run

from kakarot_scripts.constants import DECLARED_CONTRACTS
from kakarot_scripts.utils.starknet import declare, dump_declarations

# %%


async def declare_contracts():
    # %% Declare
    class_hash = {contract: await declare(contract) for contract in DECLARED_CONTRACTS}
    dump_declarations(class_hash)


# %% Run
def main_sync():
    run(declare_contracts())


# %%

if __name__ == "__main__":
    main_sync()
