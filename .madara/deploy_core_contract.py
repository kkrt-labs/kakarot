from kakarot_scripts.utils.l1 import (
    deploy_on_l1,
    get_l1_addresses,
    dump_l1_addresses
)

contract = deploy_on_l1(
    "starknet",
    "StarknetMessagingLocal",
)
l1_addresses = get_l1_addresses()
l1_addresses.update({"StarknetMessagingLocal": {"address": contract.address}})
dump_l1_addresses(l1_addresses)
