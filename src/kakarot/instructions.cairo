// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.registers import get_ap
from starkware.cairo.common.registers import get_label_location

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.push_operations import PushOperations
from kakarot.instructions.arithmetic_operations import ArithmeticOperations
from kakarot.instructions.comparison_operations import ComparisonOperations
from kakarot.instructions.duplication_operations import DuplicationOperations
from kakarot.instructions.exchange_operations import ExchangeOperations
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.instructions.block_information import BlockInformation

// @title EVM instructions processing.
// @notice This file contains functions related to the processing of EVM instructions.
// @author @abdelhamidbakhta
// @custom:namespace EVMInstructions
namespace EVMInstructions {
    // @notice Decode the current opcode and execute associated function.
    // @param instructions The instruction set.
    // @param opcode The opcode value.
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func decode_and_execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: felt*, ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;

        // Retrieve the current program counter.
        let pc = ctx.program_counter;

        // Revert if pc < 0
        with_attr error_message("Kakarot: InvalidCodeOffset") {
            assert_nn(pc);
        }

        local opcode;

        %{
            # Check if pc > len(code) and process it as a STOP if true
            if ids.pc >= ids.ctx.code_len:
                ids.opcode = 0
            else:
                ids.opcode = memory[ids.ctx.code + ids.pc]
        %}

        local opcode_exist;

        // Check if opcode exists
        %{
            if memory.get(ids.instructions + ids.opcode) == None:
                ids.opcode_exist = 0
            else:
                ids.opcode_exist = 1
        %}

        // Revert if opcode does not exist
        with_attr error_message("Kakarot: UnknownOpcode {opcode}") {
            assert opcode_exist = TRUE;
        }

        // move program counter + 1 after opcode is read
        let ctx = ExecutionContext.increment_program_counter(ctx, 1);

        // Read opcode in instruction set
        let function_codeoffset_felt = instructions[opcode];
        let function_codeoffset = cast(function_codeoffset_felt, codeoffset);
        let (function_ptr) = get_label_location(function_codeoffset);

        // Prepare implicit arguments
        let implicit_args_len = decode_and_execute.ImplicitArgs.SIZE;
        tempvar implicit_args = new decode_and_execute.ImplicitArgs(syscall_ptr, pedersen_ptr, range_check_ptr);

        // Build arguments array
        let (args_len: felt, args: felt*) = prepare_arguments(
            ctx, implicit_args_len, implicit_args
        );

        // Invoke opcode function
        invoke(function_ptr, args_len, args);

        // Retrieve results
        let (ap_val) = get_ap();
        let implicit_args: decode_and_execute.ImplicitArgs* = cast(ap_val - implicit_args_len - 1, decode_and_execute.ImplicitArgs*);
        // Update implicit arguments
        let syscall_ptr = implicit_args.syscall_ptr;
        let pedersen_ptr = implicit_args.pedersen_ptr;
        let range_check_ptr = implicit_args.range_check_ptr;

        // Get actual return value from ap
        return cast([ap_val - 1], model.ExecutionContext*);
    }

    // @notice Add an instruction in the passed instructions set
    // @param instructions the instruction set
    // @param opcode The opcode value
    // @param function the function to execute for the specified opcode
    func add_instruction{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: felt*, opcode: felt, function: codeoffset
    ) {
        assert [instructions + opcode] = cast(function, felt);
        return ();
    }

    // @notice 0x00 - STOP
    // @dev Halts execution
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 0
    // @param ctx The pointer to the execution context.
    func exec_stop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        %{ print("0x00 - STOP") %}
        return ExecutionContext.stop(ctx_ptr);
    }

    // @notice Prepare arguments for the dynamic call.
    // @param ctx The pointer to the execution context.
    // @param implicit_args_len The length of the implicit arguments.
    // @param implicit_args The implicit arguments.
    // @return The length of the arguments array,
    // @return The arguments array.
    func prepare_arguments(ctx: felt*, implicit_args_len: felt, implicit_args: felt*) -> (
        args_len: felt, args: felt*
    ) {
        alloc_locals;

        let (args: felt*) = alloc();
        memcpy(args, implicit_args, implicit_args_len);
        let ctx_value = cast(ctx, felt);
        assert args[implicit_args_len] = ctx_value;

        return (implicit_args_len + 1, args);
    }

    // @notice Generate the instructions set for the EVM.
    // @return The instructions set.
    func generate_instructions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> felt* {
        alloc_locals;
        // Init instructions
        let (instructions: felt*) = alloc();

        // Add instructions

        // Add 0s: Stop and Arithmetic Operations
        // 0x00 - STOP
        add_instruction(instructions, 0, exec_stop);
        // 0x01 - ADD
        add_instruction(instructions, 1, ArithmeticOperations.exec_add);
        // 0x02 - MUL
        add_instruction(instructions, 2, ArithmeticOperations.exec_mul);
        // 0x03 - SUB
        add_instruction(instructions, 3, ArithmeticOperations.exec_sub);
        // 0x04 - DIV
        add_instruction(instructions, 4, ArithmeticOperations.exec_div);
        // 0x05 - SDIV
        add_instruction(instructions, 5, ArithmeticOperations.exec_sdiv);
        // 0x06 - MOD
        add_instruction(instructions, 6, ArithmeticOperations.exec_mod);
        // 0x07 - SMOD
        add_instruction(instructions, 7, ArithmeticOperations.exec_smod);
        // 0x08 - ADDMOD
        add_instruction(instructions, 8, ArithmeticOperations.exec_addmod);
        // 0x09 - MULMOD
        add_instruction(instructions, 9, ArithmeticOperations.exec_mulmod);
        // 0x0A - EXP
        add_instruction(instructions, 0xA, ArithmeticOperations.exec_exp);
        // 0x0B - SIGNEXTEND
        add_instruction(instructions, 0xB, ArithmeticOperations.exec_signextend);

        // Comparison & bitwise logic operations
        // 0x10 - LT
        add_instruction(instructions, 0x10, ComparisonOperations.exec_lt);
        // 0x11 - GT
        add_instruction(instructions, 0x11, ComparisonOperations.exec_gt);
        // 0x12 - SLT
        add_instruction(instructions, 0x12, ComparisonOperations.exec_slt);
        // 0x13 - SGT
        add_instruction(instructions, 0x13, ComparisonOperations.exec_sgt);
        // 0x14 - EQ
        add_instruction(instructions, 0x14, ComparisonOperations.exec_eq);
        // 0x15 - ISZERO
        add_instruction(instructions, 0x15, ComparisonOperations.exec_iszero);

        // Environment Information
        // 0x38 - CODESIZE
        add_instruction(instructions, 0x38, EnvironmentalInformation.exec_codesize);

        // Block Information
        // 0x41 - COINBASE
        add_instruction(instructions, 0x41, BlockInformation.exec_coinbase);
        // 0x46 - CHAINID
        add_instruction(instructions, 0x46, BlockInformation.exec_chainid);

        // 0x52 - MSTORE
        add_instruction(instructions, 0x52, MemoryOperations.exec_store);

        // Add 6s: Push operations
        add_instruction(instructions, 0x60, PushOperations.exec_push1);
        add_instruction(instructions, 0x61, PushOperations.exec_push2);
        add_instruction(instructions, 0x62, PushOperations.exec_push3);
        add_instruction(instructions, 0x63, PushOperations.exec_push4);
        add_instruction(instructions, 0x64, PushOperations.exec_push5);
        add_instruction(instructions, 0x65, PushOperations.exec_push6);
        add_instruction(instructions, 0x66, PushOperations.exec_push7);
        add_instruction(instructions, 0x67, PushOperations.exec_push8);
        add_instruction(instructions, 0x68, PushOperations.exec_push9);
        add_instruction(instructions, 0x69, PushOperations.exec_push10);
        add_instruction(instructions, 0x6a, PushOperations.exec_push11);
        add_instruction(instructions, 0x6b, PushOperations.exec_push12);
        add_instruction(instructions, 0x6c, PushOperations.exec_push13);
        add_instruction(instructions, 0x6d, PushOperations.exec_push14);
        add_instruction(instructions, 0x6e, PushOperations.exec_push15);
        add_instruction(instructions, 0x6f, PushOperations.exec_push16);
        add_instruction(instructions, 0x70, PushOperations.exec_push17);
        add_instruction(instructions, 0x71, PushOperations.exec_push18);
        add_instruction(instructions, 0x72, PushOperations.exec_push19);
        add_instruction(instructions, 0x73, PushOperations.exec_push20);
        add_instruction(instructions, 0x74, PushOperations.exec_push21);
        add_instruction(instructions, 0x75, PushOperations.exec_push22);
        add_instruction(instructions, 0x76, PushOperations.exec_push23);
        add_instruction(instructions, 0x77, PushOperations.exec_push24);
        add_instruction(instructions, 0x78, PushOperations.exec_push25);
        add_instruction(instructions, 0x79, PushOperations.exec_push26);
        add_instruction(instructions, 0x7a, PushOperations.exec_push27);
        add_instruction(instructions, 0x7b, PushOperations.exec_push28);
        add_instruction(instructions, 0x7c, PushOperations.exec_push29);
        add_instruction(instructions, 0x7d, PushOperations.exec_push30);
        add_instruction(instructions, 0x7e, PushOperations.exec_push31);
        add_instruction(instructions, 0x7f, PushOperations.exec_push32);

        // Add 8s: Duplication operations
        add_instruction(instructions, 0x80, DuplicationOperations.exec_dup1);
        add_instruction(instructions, 0x81, DuplicationOperations.exec_dup2);
        add_instruction(instructions, 0x82, DuplicationOperations.exec_dup3);
        add_instruction(instructions, 0x83, DuplicationOperations.exec_dup4);
        add_instruction(instructions, 0x84, DuplicationOperations.exec_dup5);
        add_instruction(instructions, 0x85, DuplicationOperations.exec_dup6);
        add_instruction(instructions, 0x86, DuplicationOperations.exec_dup7);
        add_instruction(instructions, 0x87, DuplicationOperations.exec_dup8);
        add_instruction(instructions, 0x88, DuplicationOperations.exec_dup9);
        add_instruction(instructions, 0x89, DuplicationOperations.exec_dup10);
        add_instruction(instructions, 0x8a, DuplicationOperations.exec_dup11);
        add_instruction(instructions, 0x8b, DuplicationOperations.exec_dup12);
        add_instruction(instructions, 0x8c, DuplicationOperations.exec_dup13);
        add_instruction(instructions, 0x8d, DuplicationOperations.exec_dup14);
        add_instruction(instructions, 0x8e, DuplicationOperations.exec_dup15);
        add_instruction(instructions, 0x8f, DuplicationOperations.exec_dup16);

        // Add 9s: Exchange operations
        add_instruction(instructions, 0x90, ExchangeOperations.exec_swap1);
        add_instruction(instructions, 0x91, ExchangeOperations.exec_swap2);
        add_instruction(instructions, 0x92, ExchangeOperations.exec_swap3);
        add_instruction(instructions, 0x93, ExchangeOperations.exec_swap4);
        add_instruction(instructions, 0x94, ExchangeOperations.exec_swap5);
        add_instruction(instructions, 0x95, ExchangeOperations.exec_swap6);
        add_instruction(instructions, 0x96, ExchangeOperations.exec_swap7);
        add_instruction(instructions, 0x97, ExchangeOperations.exec_swap8);
        add_instruction(instructions, 0x98, ExchangeOperations.exec_swap9);
        add_instruction(instructions, 0x99, ExchangeOperations.exec_swap10);
        add_instruction(instructions, 0x9a, ExchangeOperations.exec_swap11);
        add_instruction(instructions, 0x9b, ExchangeOperations.exec_swap12);
        add_instruction(instructions, 0x9c, ExchangeOperations.exec_swap13);
        add_instruction(instructions, 0x9d, ExchangeOperations.exec_swap14);
        add_instruction(instructions, 0x9e, ExchangeOperations.exec_swap15);
        add_instruction(instructions, 0x9f, ExchangeOperations.exec_swap16);

        return instructions;
    }
}
