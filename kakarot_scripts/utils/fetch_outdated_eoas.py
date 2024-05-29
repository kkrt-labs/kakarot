import asyncio
import json

from starknet_py.net.full_node_client import FullNodeClient
from starkware.starknet.public.abi import get_selector_from_name

node_url = (
    "https://juno-kakarot-dev.karnot.xyz/"  # update with priority RPC URL if required
)
client = FullNodeClient(node_url=node_url)
LATEST_CLASS_HASH = 0x1276D0B017701646F8646B69DE6C3B3584EDCE71879678A679F28C07A9971CF


async def get_class_hash(address):
    class_hash = await client.get_class_hash_at(address)
    return address, class_hash


async def get_storage(address):
    storage = await client.get_storage_at(
        address, get_selector_from_name("Account_bytecode_len")
    )
    return address, storage


async def main():
    evm_contract_deployed_events = (
        await client.get_events(
            keys=[[get_selector_from_name("evm_contract_deployed")]],
            chunk_size=10240,
        )
    ).events

    evm_to_starknet = {
        event.data[0]: event.data[1] for event in evm_contract_deployed_events
    }
    starknet_addresses = list(evm_to_starknet.values())

    batch_size = 50
    account_classes = {}
    for i in range(0, len(starknet_addresses), batch_size):
        batch = starknet_addresses[i : i + batch_size]
        results = await asyncio.gather(
            *[asyncio.create_task(get_class_hash(address)) for address in batch]
        )
        account_classes.update(dict(results))
        print(
            f"Processed batch {i // batch_size + 1} of {len(starknet_addresses) // batch_size + 1} for get_class_hash"
        )

    outdated_accounts = [
        address
        for address, class_hash in account_classes.items()
        if class_hash != LATEST_CLASS_HASH
    ]

    eoa_accounts = []
    for i in range(0, len(outdated_accounts), batch_size):
        batch = outdated_accounts[i : i + batch_size]
        results = await asyncio.gather(
            *[asyncio.create_task(get_storage(address)) for address in batch]
        )
        eoa_accounts.extend(address for address, storage in results if storage == 0)
        print(
            f"Processed batch {i // batch_size + 1} of {len(outdated_accounts) // batch_size + 1} for get_storage"
        )

    outdated_evm_classes = [
        f"0x{evm_address:040x}"
        for evm_address, starknet_address in evm_to_starknet.items()
        if starknet_address in eoa_accounts
    ]

    with open("outdated_evm_classes.json", "w") as f:
        json.dump(outdated_evm_classes, f, indent=4)


asyncio.run(main())
