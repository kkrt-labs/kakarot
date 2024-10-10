from kakarot_scripts.constants import DECLARED_CONTRACTS
from kakarot_scripts.utils.starknet import declare, dump_declarations


async def declare_contracts():
    class_hash = {contract: await declare(contract) for contract in DECLARED_CONTRACTS}
    dump_declarations(class_hash)


if __name__ == "__main__":
    from uvloop import run

    async def main():
        await declare_contracts()

    run(main())
