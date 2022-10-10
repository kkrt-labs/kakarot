// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256

// Project dependencies
from openzeppelin.security.safemath.library import SafeUint256

// Internal dependencies
from zkairvm.model import model
from utils.utils import Helpers
from zkairvm.execution_context import ExecutionContext
from zkairvm.stack import Stack

namespace EVMInstructions {
    // Generates the instructions set for the EVM
    func generate_instructions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (instructions: felt*) {
        alloc_locals;
        // init instructions
        let (local instructions: felt*) = alloc();

        // add instructions

        // add 0s: Stop and Arithmetic Operations
        // 0x00 - STOP
        add_instruction(instructions, 0, exec_stop);
        // 0x01 - ADD
        add_instruction(instructions, 1, exec_add);

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
        instructions: felt*, ctx: model.ExecutionContext
    ) {
        alloc_locals;
        let (pc) = ExecutionContext.get_pc(ctx);

        // revert if pc < 0
        with_attr error_message("Zkairvm: InvalidCodeOffset") {
            assert_nn(pc);
        }

        local opcode;

        // <START CAIRO VERSION>
        // check if pc > len(code) and process it as a STOP if true
        // let is_pc_gt_code_len = is_le(ctx.code_len, pc);
        // if (is_pc_gt_code_len == TRUE) {
        // opcode = 0;
        // } else {
        // read current opcode
        // TODO: find a workaround re: Expected a constant offset in the range [-2^15, 2^15).
        // opcode = [ctx.code + pc]
        // }
        // <END  CAIRO VERSION>

        // <START HINT VERSION
        %{
            # check if pc > len(code) and process it as a STOP if true
            if ids.pc > ids.ctx.code_len:
                ids.opcode = 0
            else:
                ids.opcode = memory[ids.ctx.code + ids.pc]
        %}
        // <END  HINT VERSION

        local opcode_exist;

        // check if opcode exists
        %{
            if memory.get(ids.instructions + ids.opcode) == None:
                ids.opcode_exist = 0
            else:
                ids.opcode_exist = 1
        %}

        // revert if opcode does not exist
        with_attr error_message("Zkairvm: UnknownOpcode") {
            assert opcode_exist = TRUE;
        }

        // read opcode in instruction set
        let function_codeoffset_felt = instructions[opcode];
        let function_codeoffset = cast(function_codeoffset_felt, codeoffset);
        let (function_ptr) = get_label_location(function_codeoffset);

        // prepare arguments
        let (local args: model.ExecutionContext*) = alloc();
        assert [args] = ctx;

        invoke(function_ptr, model.ExecutionContext.SIZE, args);

        return ();
    }
    // Adds an instruction in the passed instructions set
    // @param instructions the instruction set
    // @param opcode the opcode value
    // @param function the function to execute for the specified opcode
    func add_instruction{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: felt*, opcode: felt, function: codeoffset
    ) {
        alloc_locals;
        assert [instructions + opcode] = cast(function, felt);
        return ();
    }

    // 0x00 - STOP
    // Halts execution
    // Since: Frontier
    // Group: Stop and Arithmetic Operations
    func exec_stop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x00 - STOP") %}
        ExecutionContext.stop(ctx);
        return ();
    }

    // 0x00 - ADD
    // Addition operation
    // Since: Frontier
    // Group: Stop and Arithmetic Operations
    func exec_add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x01 - ADD") %}
        // TODO: implement me

        // tempvar syscall_ptr: felt* = syscall_ptr;
        // let (stack) = ExecutionContext.get_stack{syscall_ptr=syscall_ptr}(ctx);

        // Stack input:
        // 0 - a: first integer value to add.
        // 1 - b: second integer value to add.

        // We should pop values, pop is not implemented yet
        // Hence we use peek for testing purpose
        // let (a) = Stack.pop(stack);
        // let (b) = Stack.pop(stack);

        // let (a) = Stack.peek(0);
        // let (b) = Stack.peek(1);

        // compute the addition
        // let (result) = SafeUint256.add(a, b);

        // Stack output:
        // a + b: integer result of the addition modulo 2^256
        // Stack.push(stack, result);

        // move program counter
        ExecutionContext.inc_pc(ctx, 1);
        return ();
    }
}
