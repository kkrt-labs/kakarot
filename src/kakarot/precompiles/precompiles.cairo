// SPDX-License-Identifier: MIT

%lang starknet
// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.math_cmp import is_le, is_not_zero

// Internal dependencies
from kakarot.account import Account
from kakarot.constants import Constants
from kakarot.evm import EVM
from kakarot.errors import Errors
from kakarot.model import model
from kakarot.precompiles.blake2f import PrecompileBlake2f
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.precompiles.ec_recover import PrecompileEcRecover
from kakarot.precompiles.ripemd160 import PrecompileRIPEMD160
from kakarot.precompiles.sha256 import PrecompileSHA256

// @title Precompile related functions.
// @notice This file contains functions related to the running of precompiles.
// @author @jobez
// @custom:namespace Precompile
namespace Precompiles {
    // @notice Executes a precompile at a given precompile address
    // @dev Associates gas used and precompile return values to a execution subcontext
    // @param evm_address The precompile evm_address to be executed
    // @param calldata_len The calldata length
    // @param calldata The calldata.
    // @param value The value.
    // @param parent The calling context.
    // @param gas_left The gas left.
    // @return EVM The initialized execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        evm_address: felt,
        calldata_len: felt,
        calldata: felt*,
        value: felt,
        parent: model.Parent*,
        gas_left: felt,
    ) -> model.EVM* {
        alloc_locals;

        // Build returned execution context
        let (starknet_address) = Account.compute_starknet_address(evm_address);
        tempvar address = new model.Address(starknet_address, evm_address);
        tempvar message = new model.Message(
            bytecode=cast(0, felt*),
            bytecode_len=0,
            calldata=cast(0, felt*),
            calldata_len=0,
            value=0,
            gas_price=0,
            origin=parent.evm.message.origin,
            parent=parent,
            address=address,
            read_only=FALSE,
            is_create=FALSE,
            depth=parent.evm.message.depth + 1,
        );
        let evm = EVM.init(message, gas_left);

        // Execute the precompile at a given evm_address
        let (output_len, output, gas_used, reverted) = _exec_precompile(
            evm_address, calldata_len, calldata
        );
        let evm = EVM.charge_gas(evm, gas_used);
        let evm = EVM.stop(evm, output_len, output, reverted);

        return evm;
    }

    func is_precompile{range_check_ptr}(address: felt) -> felt {
        return is_not_zero(address) * is_le(address, Constants.LAST_PRECOMPILE_ADDRESS);
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
    func _exec_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
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
        call not_whitelisted_precompile;  // 0x2
        ret;
        call PrecompileRIPEMD160.run;  // 0x3
        ret;
        call PrecompileDataCopy.run;  // 0x4
        ret;
        call not_whitelisted_precompile;  // 0x5
        ret;
        call not_whitelisted_precompile;  // 0x6
        ret;
        call not_whitelisted_precompile;  // 0x7
        ret;
        call not_implemented_precompile;  // 0x8
        ret;
        call PrecompileBlake2f.run;  // 0x9
        ret;
    }

    // @notice A placeholder for precompile that are not implemented yet.
    // @dev Halts execution.
    // @param evm_address The evm_address.
    // @param _input_len The length of the input array.
    // @param _input The input array.
    func unknown_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, _input_len: felt, _input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        let (revert_reason_len, revert_reason) = Errors.unknownPrecompile(evm_address);
        return (revert_reason_len, revert_reason, 0, 1);
    }

    // @notice A placeholder for precompile that are not implemented yet.
    // @dev Halts execution.
    // @param evm_address The evm_address.
    // @param _input_len The length of the input array.
    // @param _input The input array.
    func not_implemented_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, _input_len: felt, _input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        let (revert_reason_len, revert_reason) = Errors.notImplementedPrecompile(evm_address);
        return (revert_reason_len, revert_reason, 0, 1);
    }

    // @notice A placeholder for precompile that are not implemented yet.
    // @dev Halts execution.
    // @param evm_address The evm_address.
    // @param _input_len The length of the input array.
    // @param _input The input array.
    func not_whitelisted_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, _input_len: felt, _input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        let (revert_reason_len, revert_reason) = Errors.notImplementedPrecompile(evm_address);
        return (revert_reason_len, revert_reason, 0, 1);
    }
}
