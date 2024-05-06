%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_in_range
from starkware.starknet.common.syscalls import library_call
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from kakarot.interfaces.interfaces import ICairo1Helpers
from kakarot.storages import Kakarot_cairo1_helpers_class_hash
from kakarot.errors import Errors
from kakarot.precompiles.blake2f import PrecompileBlake2f
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.precompiles.ec_recover import PrecompileEcRecover
from kakarot.precompiles.p256verify import PrecompileP256Verify
from kakarot.precompiles.ripemd160 import PrecompileRIPEMD160
from kakarot.precompiles.sha256 import PrecompileSHA256

const LAST_ETHEREUM_PRECOMPILE_ADDRESS = 0x0a;
const FIRST_ROLLUP_PRECOMPILE_ADDRESS = 0x100;
const LAST_ROLLUP_PRECOMPILE_ADDRESS = 0x100;
const EXEC_PRECOMPILE_SELECTOR = 0x01e3e7ac032066525c37d0791c3c0f5fbb1c17f1cb6fe00afc206faa3fbd18e1;

// @title Precompile related functions.
namespace Precompiles {
    func is_precompile{range_check_ptr}(address: felt) -> felt {
        let is_rollup_precompile_ = is_rollup_precompile(address);
        return is_not_zero(address) * (
            is_le(address, LAST_ETHEREUM_PRECOMPILE_ADDRESS) + is_rollup_precompile_
        );
    }

    // @notice Return whether the address is a RIP precompile, starting from addresses 0x100.
    func is_rollup_precompile{range_check_ptr}(address: felt) -> felt {
        return is_in_range(
            address, FIRST_ROLLUP_PRECOMPILE_ADDRESS, LAST_ROLLUP_PRECOMPILE_ADDRESS + 1
        );
    }

    // @notice Executes associated function of precompiled evm_address.
    // @dev This function uses an internal jump table to execute the corresponding precompile impmentation.
    // @param evm_address The precompile evm_address.
    // @param input_len The length of the input array.
    // @param input The input array.
    // @return output_len The output length.
    // @return output The output array.
    // @return gas_used The gas usage of precompile.
    // @return reverted Whether the precompile ran successfully or not
    func exec_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        let is_rollup_precompile_ = is_rollup_precompile(evm_address);
        if (is_rollup_precompile_ != 0) {
            // Rollup precompiles start at address 0x100
            tempvar offset = 1 + 3 * (evm_address - FIRST_ROLLUP_PRECOMPILE_ADDRESS);

            [ap] = syscall_ptr, ap++;
            [ap] = pedersen_ptr, ap++;
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = evm_address, ap++;
            [ap] = input_len, ap++;
            [ap] = input, ap++;

            jmp rel offset;
            call PrecompileP256Verify.run;  // 0x100
            ret;
        }

        // Compute the corresponding offset in the jump table:
        // count 1 for "next line" and 3 steps per precompile evm_address: call, precompile, ret
        tempvar offset = 1 + 3 * evm_address;

        // Prepare arguments
        [ap] = syscall_ptr, ap++;
        [ap] = pedersen_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = bitwise_ptr, ap++;
        [ap] = evm_address, ap++;
        [ap] = input_len, ap++;
        [ap] = input, ap++;

        // call precompile evm_address
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
