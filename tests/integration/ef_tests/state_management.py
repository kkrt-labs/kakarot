from starkware.cairo.lang.vm.crypto import pedersen_hash
from starkware.starknet.public.abi import get_storage_var_address
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract

from tests.utils.constants import MAX_INT
from tests.utils.helpers import hex_string_to_bytes_array
from tests.utils.uint256 import int_to_uint256

# In normal kakarot deployment, contracts handle necessary state when they are constructed.
# In order to be able to follow the address conventions of ef tests,
# we have to manipulate the starknet state manually.
# Thus we have to manually update contract storage keys as they would be set in normal construction.


# Here is the common storage entries that both eoa's and evm contracts must have.
def construct_common_storage_entries(evm_address, class_hash):
    return {
        "is_initialized_": 1,
        "evm_address": evm_address,
        "_implementation": class_hash,
    }


# We build off the base for specific dimensions for contracts
def construct_storage_entries_for_contract(class_hash, evm_address, kakarot_address):
    contract = construct_common_storage_entries(evm_address, class_hash)

    contract.update(
        {
            "Ownable_owner": kakarot_address,
        }
    )

    return contract


def construct_storage_entries_for_eoa(
    class_hash, evm_address, kakarot_address, starknet_address
):
    eoa = construct_common_storage_entries(evm_address, class_hash)

    eoa.update({"kakarot_address": kakarot_address, "nonce": 1})

    return eoa


async def write_storage(starknet, starknet_address, storage_entries):
    for key, value in storage_entries.items():
        await starknet.state.state.set_storage_at(
            contract_address=starknet_address,
            key=get_storage_var_address(key),
            value=value,
        )


async def write_test_state_for_contract(
    contract_class_hash: DeclaredClass,
    proxy_class_hash: DeclaredClass,
    contract: StarknetContract,
    kakarot: StarknetContract,
    starknet: StarknetContract,
    state,
    evm_address,
    starknet_address,
):
    # Every contract is kept in a map to its evm contract in a Kakarot storage variable.
    await starknet.state.state.set_storage_at(
        contract_address=kakarot.contract_address,
        key=pedersen_hash(
            get_storage_var_address("evm_to_starknet_address"), evm_address
        ),
        value=starknet_address,
    )

    storage_entries = construct_storage_entries_for_contract(
        contract_class_hash,
        evm_address,
        kakarot.contract_address,
    )
    await write_storage(starknet, starknet_address, storage_entries)
    await starknet.state.state.set_class_hash_at(
        contract_address=starknet_address,
        class_hash=proxy_class_hash,
    )
    await contract.write_bytecode(hex_string_to_bytes_array(state["code"])).execute(
        caller_address=kakarot.contract_address
    )


async def write_test_state_for_eoa(
    eoa_class_hash: DeclaredClass,
    proxy_class_hash: DeclaredClass,
    kakarot: StarknetContract,
    starknet: StarknetContract,
    state,
    evm_address,
    starknet_address,
):
    storage_entries = construct_storage_entries_for_eoa(
        eoa_class_hash,
        evm_address,
        kakarot.contract_address,
        starknet_address,
    )

    await write_storage(starknet, starknet_address, storage_entries)
    await starknet.state.state.set_class_hash_at(
        contract_address=starknet_address,
        class_hash=proxy_class_hash,
    )


async def fund_and_set_allowance(eth, kakarot_address, address, balance):
    max_allowance = int_to_uint256(MAX_INT)
    # mock account gets paid
    await eth.mint(address, balance).execute()
    # In regular kakarot deployment, this is handled on construction.
    # We do this manually in order to be able to do tranfsers from our manually deployed accounts.
    await eth.approve(kakarot_address, max_allowance).execute(caller_address=address)
