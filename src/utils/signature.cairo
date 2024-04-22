%lang starknet

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.cairo_secp.bigint3 import BigInt3, UnreducedBigInt3
from starkware.cairo.common.cairo_secp.signature import validate_signature_entry
from starkware.cairo.common.uint256 import Uint256
from kakarot.interfaces.interfaces import ICairo1Helpers
from starkware.cairo.common.cairo_secp.bigint import uint256_to_bigint

namespace Signature {
    // A version of verify_eth_signature, with that msg_hash, r and s as Uint256 and
    // using the Cairo1 helpers class.
    func verify_eth_signature_uint256{
        syscall_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
    }(msg_hash: Uint256, r: Uint256, s: Uint256, v: felt, eth_address: felt, helpers_class: felt) {
        alloc_locals;
        let (msg_hash_bigint: BigInt3) = uint256_to_bigint(msg_hash);
        let (r_bigint: BigInt3) = uint256_to_bigint(r);
        let (s_bigint: BigInt3) = uint256_to_bigint(s);

        with_attr error_message("Signature out of range.") {
            validate_signature_entry(r_bigint);
            validate_signature_entry(s_bigint);
        }

        with_attr error_message("Invalid signature.") {
            let (success, recovered_address) = ICairo1Helpers.library_call_recover_eth_address(
                class_hash=helpers_class, msg_hash=msg_hash, r=r, s=s, y_parity=v
            );
            assert success = 1;
            assert eth_address = recovered_address;
        }
        return ();
    }
}
