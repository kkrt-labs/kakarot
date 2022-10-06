// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_write, dict_read, dict_update
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.registers import get_label_location

// Internal dependencies
from zkairvm.model import ExecutionContext

namespace EVMInstructions {
    // Generates the instructions set for the EVM
    func generate_instructions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (instructions: DictAccess*) {
        alloc_locals;
        let initial_value = 0;
        // init dict
        let (instructions: DictAccess*) = default_dict_new(default_value=initial_value);

        // add instructions

        // add 0s: Stop and Arithmetic Operations
        add_instruction(instructions, 0, exec_stop);  // 0x00 - STOP

        return (instructions=instructions);
    }

    // Decodes the current opcode and execute associated function
    // @param instructions the instruction set
    // @param opcode the opcode value
    // @param ctx the execution context
    func decode_and_execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: DictAccess*, ctx: ExecutionContext
    ) {
        alloc_locals;

        // TODO: check if pc < 0 and revert with InvalidCodeOffset
        // TODO: check if pc > len(code) and process it as a STOP if true

        // read current opcode
        let opcode = ctx.code[ctx.pc];

        // read opcode in instruction set
        let (function_ptr_as_felt) = dict_read{dict_ptr=instructions}(key=opcode);
        let function_ptr = cast(function_ptr_as_felt, felt*);

        // prepare arguments
        // TODO: prepare arguments

        // execute the function
        // TODO: invoke the function
        return ();
    }
    // Adds an instruction in the passed instructions set
    // @param instructions the instruction set
    // @param opcode the opcode value
    // @param function the function to execute for the specified opcode
    func add_instruction{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: DictAccess*, opcode: felt, function: codeoffset
    ) {
        alloc_locals;
        let (function_ptr) = get_label_location(function);
        let function_ptr_as_felt = cast(function_ptr, felt);
        dict_write{dict_ptr=instructions}(key=opcode, new_value=function_ptr_as_felt);
        return ();
    }

    // 0x00 - STOP
    // Halts execution
    // Since: Frontier
    // Group: Stop and Arithmetic Operations
    func exec_stop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        return ();
    }
}
