%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from kakarot.storages import Kakarot_patched_addresses, Kakarot_original_patched_addresses

func patched_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> felt {
    let (patch) = Kakarot_patched_addresses.read(evm_address);

    if (patch != 0) {
        return patch;
    }

    return evm_address;
}
