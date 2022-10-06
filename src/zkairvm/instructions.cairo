// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.registers import get_label_location

// Internal dependencies
from zkairvm.model import ExecutionContext

namespace EVMInstructions {
    // Define constants
    const BYTE_MAX_VALUE = 255;
    const OPCODE_MAX_VALUE = BYTE_MAX_VALUE;
    const UNKNOWN_OPCODE_VALUE = OPCODE_MAX_VALUE + 1;
    const INSTRUCTIONS_LEN = OPCODE_MAX_VALUE + 1;

    // Generates the instructions set for the EVM
    func generate_instructions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (instructions: codeoffset*) {
        alloc_locals;
        // init instructions
        let (instructions_len, instructions) = new_array_with_default_value(
            OPCODE_MAX_VALUE + 1, unknown_opcode
        );

        // add instructions

        // add 0s: Stop and Arithmetic Operations
        // add_instruction(instructions, 0, exec_stop);  // 0x00 - STOP

        return (instructions=instructions);
    }

    func new_array_with_default_value(array_len: felt, default_value: codeoffset) -> (
        array_len: felt, array: codeoffset*
    ) {
        alloc_locals;
        let (local array: codeoffset*) = alloc();
        fill_with_value(array_len, array, default_value);
        return (array_len, array);
    }

    func fill_with_value(array_len: felt, array: codeoffset*, value: codeoffset) {
        alloc_locals;
        if (array_len == 0) {
            return ();
        }
        assert [array] = value;
        fill_with_value(array_len - 1, array + 1, value);
        return ();
    }

    // Decodes the current opcode and execute associated function
    // @param instructions the instruction set
    // @param opcode the opcode value
    // @param ctx the execution context
    func decode_and_execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: codeoffset*, ctx: ExecutionContext
    ) {
        alloc_locals;

        // TODO: check if pc < 0 and revert with InvalidCodeOffset
        // TODO: check if pc > len(code) and process it as a STOP if true

        // read current opcode
        let opcode = ctx.code[ctx.pc];

        // read opcode in instruction set
        // let function_codeoffset = instructions[opcode];

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
        instructions: codeoffset*, opcode: felt, function: codeoffset
    ) {
        alloc_locals;
        assert [instructions + opcode] = function;
        return ();
    }

    // Unknow opcode
    func unknown_opcode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        // TODO: revert with UnknownOpcode error
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
        %{ print("0x00 - STOP") %}
        return ();
    }

    // 0x00 - ADD
    // Addition operation
    // Since: Frontier
    // Group: Stop and Arithmetic Operations
    func exec_add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x01 - ADD") %}
        return ();
    }
}
