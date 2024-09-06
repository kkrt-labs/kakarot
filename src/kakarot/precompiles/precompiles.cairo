%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_nn, is_not_zero, is_in_range
from starkware.starknet.common.syscalls import library_call
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.memcpy import memcpy

from kakarot.interfaces.interfaces import ICairo1Helpers
from kakarot.storages import Kakarot_cairo1_helpers_class_hash
from kakarot.errors import Errors
from kakarot.precompiles.blake2f import PrecompileBlake2f
from kakarot.precompiles.kakarot_precompiles import KakarotPrecompiles
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.precompiles.ec_recover import PrecompileEcRecover
from kakarot.precompiles.p256verify import PrecompileP256Verify
from kakarot.precompiles.ripemd160 import PrecompileRIPEMD160
from kakarot.precompiles.sha256 import PrecompileSHA256
from kakarot.precompiles.precompiles_helpers import (
    PrecompilesHelpers,
    LAST_ETHEREUM_PRECOMPILE_ADDRESS,
    FIRST_ROLLUP_PRECOMPILE_ADDRESS,
    FIRST_KAKAROT_PRECOMPILE_ADDRESS,
)
from utils.utils import Helpers

// @title Precompile related functions.
namespace Precompiles {
    // @notice Executes associated function of precompiled evm_address.
    // @dev This function uses an internal jump table to execute the corresponding precompile impmentation.
    // @param precompile_address The precompile evm_address.
    // @param input_len The length of the input array.
    // @param input The input array.
    // @param caller_code_address The address of the code of the contract that calls the precompile.
    // @param caller_address The address of the caller of the precompile. Delegatecall rules apply.
    // @return output_len The output length.
    // @return output The output array.
    // @return gas_used The gas usage of precompile.
    // @return reverted Whether the precompile ran successfully or not
    func exec_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        precompile_address: felt,
        input_len: felt,
        input: felt*,
        caller_code_address: felt,
        caller_address: felt,
    ) -> (output_len: felt, output: felt*, gas_used: felt, reverted: felt) {
        let is_eth_precompile = is_nn(LAST_ETHEREUM_PRECOMPILE_ADDRESS - precompile_address);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        jmp eth_precompile if is_eth_precompile != 0;

        let is_rollup_precompile_ = PrecompilesHelpers.is_rollup_precompile(precompile_address);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        jmp rollup_precompile if is_rollup_precompile_ != 0;

        let is_kakarot_precompile_ = PrecompilesHelpers.is_kakarot_precompile(precompile_address);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        jmp kakarot_precompile if is_kakarot_precompile_ != 0;
        jmp unauthorized_call;

        eth_precompile:
        tempvar index = precompile_address;
        jmp call_precompile;

        rollup_precompile:
        tempvar index = (LAST_ETHEREUM_PRECOMPILE_ADDRESS + 1) + (
            precompile_address - FIRST_ROLLUP_PRECOMPILE_ADDRESS
        );
        jmp call_precompile;

        unauthorized_call:
        // Prepare arguments if none of the above conditions are met
        [ap] = syscall_ptr, ap++;
        [ap] = pedersen_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = bitwise_ptr, ap++;
        call unauthorized_precompile;
        ret;

        call_precompile:
        // Compute the corresponding offset in the jump table:
        // count 1 for "next line" and 3 steps per index: call, precompile, ret
        tempvar offset = 1 + 3 * index;

        // Prepare arguments
        [ap] = syscall_ptr, ap++;
        [ap] = pedersen_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = bitwise_ptr, ap++;
        [ap] = precompile_address, ap++;
        [ap] = input_len, ap++;
        [ap] = input, ap++;

        // call precompile precompile_address
        jmp rel offset;
        call unknown_precompile;  // 0x0
        ret;
        call PrecompileEcRecover.run;  // 0x1
        ret;
        call external_precompile;  // 0x2
        ret;
        call PrecompileRIPEMD160.run;  // 0x3
        ret;
        call PrecompileDataCopy.run;  // 0x4
        ret;
        call external_precompile;  // 0x5
        ret;
        call not_implemented_precompile;  // 0x6
        ret;
        call not_implemented_precompile;  // 0x7
        ret;
        call not_implemented_precompile;  // 0x8
        ret;
        call PrecompileBlake2f.run;  // 0x9
        ret;
        call not_implemented_precompile;  // 0x0a: POINT_EVALUATION_PRECOMPILE
        ret;
        // Rollup precompiles. Offset must have been computed appropriately,
        // based on the address of the precompile and the last ethereum precompile
        call PrecompileP256Verify.run;  // offset 0x0b: precompile 0x100
        ret;

        kakarot_precompile:
        let is_whitelisted = KakarotPrecompiles.is_caller_whitelisted(caller_code_address);
        tempvar is_not_authorized = 1 - is_whitelisted;
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
        jmp unauthorized_call if is_not_authorized != 0;

        tempvar index = precompile_address - FIRST_KAKAROT_PRECOMPILE_ADDRESS;
        tempvar offset = 1 + 3 * index;

        // Prepare arguments
        [ap] = syscall_ptr, ap++;
        [ap] = pedersen_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = bitwise_ptr, ap++;
        [ap] = input_len, ap++;
        [ap] = input, ap++;
        [ap] = caller_address, ap++;

        // Kakarot precompiles. Offset must have been computed appropriately,
        // based on the total number of kakarot precompiles
        jmp rel offset;
        call KakarotPrecompiles.cairo_precompile;  // offset 0x0c: precompile 0x75001
        ret;
        call KakarotPrecompiles.cairo_message;  // offset 0x0d: precompile 0x75002
        ret;
    }

    // @notice A placeholder for attempts to call a precompile without permissions
    // @dev Halts execution.
    // @param evm_address The evm_address.
    // @param input_len The length of the input array.
    // @param input The input array.
    func unauthorized_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (output_len: felt, output: felt*, gas_used: felt, reverted: felt) {
        let (revert_reason_len, revert_reason) = Errors.unauthorizedPrecompile();
        return (revert_reason_len, revert_reason, 0, Errors.REVERT);
    }

    // @notice A placeholder for precompile that don't exist.
    // @dev Halts execution.
    // @param evm_address The evm_address.
    // @param input_len The length of the input array.
    // @param input The input array.
    func unknown_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        let (revert_reason_len, revert_reason) = Errors.unknownPrecompile(evm_address);
        return (revert_reason_len, revert_reason, 0, Errors.EXCEPTIONAL_HALT);
    }

    // @notice A placeholder for precompile that are not implemented yet.
    // @dev Halts execution.
    // @param evm_address The evm_address.
    // @param input_len The length of the input array.
    // @param input The input array.
    func not_implemented_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        let (revert_reason_len, revert_reason) = Errors.notImplementedPrecompile(evm_address);
        return (revert_reason_len, revert_reason, 0, Errors.EXCEPTIONAL_HALT);
    }

    func external_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;
        let (implementation) = Kakarot_cairo1_helpers_class_hash.read();
        let (calldata: felt*) = alloc();
        assert [calldata] = evm_address;
        assert [calldata + 1] = input_len;
        memcpy(calldata + 2, input, input_len);
        let (
            success, gas, return_data_len, return_data
        ) = ICairo1Helpers.library_call_exec_precompile(
            class_hash=implementation, address=evm_address, data_len=input_len, data=input
        );

        return (return_data_len, return_data, gas, 1 - success);
    }
}
