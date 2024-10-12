%lang starknet
from starkware.cairo.common.math_cmp import is_nn, is_not_zero, is_in_range
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from kakarot.constants import Constants
from utils.utils import Helpers
from kakarot.storages import Kakarot_authorized_cairo_precompiles_callers

const LAST_ETHEREUM_PRECOMPILE_ADDRESS = 0x0a;
const FIRST_ROLLUP_PRECOMPILE_ADDRESS = Constants.P256VERIFY_PRECOMPILE;
const LAST_ROLLUP_PRECOMPILE_ADDRESS = Constants.P256VERIFY_PRECOMPILE;
const FIRST_KAKAROT_PRECOMPILE_ADDRESS = Constants.CAIRO_CALL_PRECOMPILE;
const LAST_KAKAROT_PRECOMPILE_ADDRESS = Constants.CAIRO_BATCH_CALL_PRECOMPILE;

namespace PrecompilesHelpers {
    func is_rollup_precompile{range_check_ptr}(address: felt) -> felt {
        return is_in_range(
            address, FIRST_ROLLUP_PRECOMPILE_ADDRESS, LAST_ROLLUP_PRECOMPILE_ADDRESS + 1
        );
    }

    func is_kakarot_precompile{range_check_ptr}(address: felt) -> felt {
        return is_in_range(
            address, FIRST_KAKAROT_PRECOMPILE_ADDRESS, LAST_KAKAROT_PRECOMPILE_ADDRESS + 1
        );
    }
    // @notice Return whether the address is a precompile address.
    // @dev Ethereum precompiles start at address 0x01.
    // @dev RIP precompiles start at address FIRST_ROLLUP_PRECOMPILE_ADDRESS.
    // @dev Kakarot precompiles start at address FIRST_KAKAROT_PRECOMPILE_ADDRESS.
    func is_precompile{range_check_ptr}(address: felt) -> felt {
        alloc_locals;
        let is_rollup_precompile_ = is_rollup_precompile(address);
        let is_kakarot_precompile_ = is_kakarot_precompile(address);
        return is_not_zero(address) * (
            is_nn(LAST_ETHEREUM_PRECOMPILE_ADDRESS - address) +
            is_rollup_precompile_ +
            is_kakarot_precompile_
        );
    }

    // @notice Return whether the precompile address requires a whitelist.
    // @dev The Cairo Call precompile must be whitelisted, as we can use it with DELEGATECALL / CALLCODE
    // to preserve the msg.sender of the contract that calls this precompile. Use case: DualVM tokens.
    // @dev The Cairo Messaging precompile must be whitelisted, as we format the message payload in a specific Solidity contract.
    // @param precompile_address The address of the precompile.
    // @return Whether the precompile address requires a whitelist.
    func requires_whitelist(precompile_address: felt) -> felt {
        if (precompile_address == Constants.CAIRO_CALL_PRECOMPILE) {
            return TRUE;
        }
        if (precompile_address == Constants.CAIRO_MESSAGING_PRECOMPILE) {
            return TRUE;
        }
        return FALSE;
    }

    // @notice Returns whether the caller is whitelisted to call precompiles.
    // @param caller_address The address of the caller.
    // @return Whether the caller is whitelisted.
    func is_caller_whitelisted{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller_address: felt
    ) -> felt {
        let (res) = Kakarot_authorized_cairo_precompiles_callers.read(caller_address);
        return res;
    }

    // @notice Returns whether the call to the precompile is authorized.
    // @dev A call is authorized if:
    // a. The precompile requires a whitelist AND the CODE_ADDRESS of the caller is whitelisted
    // b. The precompile is CAIRO_BATCH_CALL_PRECOMPILE and the precompile address is the same as the message address (NOT a DELEGATECALL / CALLCODE).
    // @param precompile_address The address of the precompile.
    // @param caller_code_address The code_address of the precompile caller.
    // @param caller_address The address of the caller.
    // @param message_address The address being executed in the current message.
    // @return Whether the call is authorized.
    func is_call_authorized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        precompile_address: felt,
        caller_code_address: felt,
        caller_address: felt,
        message_address: felt,
    ) -> felt {
        alloc_locals;
        let precompile_requires_whitelist = requires_whitelist(precompile_address);

        // Ensure that calls to precompiles that require a whitelist are properly authorized.
        if (precompile_requires_whitelist == TRUE) {
            let is_whitelisted = is_caller_whitelisted(caller_code_address);
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            tempvar authorized = is_whitelisted;
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            tempvar authorized = TRUE;
        }
        let syscall_ptr = cast([ap - 4], felt*);
        let pedersen_ptr = cast([ap - 3], HashBuiltin*);
        let range_check_ptr = [ap - 2];
        let authorized = [ap - 1];

        // Ensure that calls to CAIRO_BATCH_CALL_PRECOMPILE are not made through a delegatecall / callcode.
        if (precompile_address == Constants.CAIRO_BATCH_CALL_PRECOMPILE) {
            let is_not_delegatecall = Helpers.is_zero(message_address - precompile_address);
            tempvar authorized = authorized * is_not_delegatecall;
        } else {
            tempvar authorized = authorized;
        }
        return authorized;
    }
}
