// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_le_felt
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
from kakarot.instructions.logging_operations import LoggingOperations
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.instructions.block_information import BlockInformation
from kakarot.instructions.system_operations import SystemOperations
from kakarot.instructions.sha3 import Sha3

// @title EVM instructions processing.
// @notice This file contains functions related to the processing of EVM instructions.
// @author @abdelhamidbakhta
// @custom:namespace EVMInstructions
namespace EVMInstructions {
    // @notice Decode the current opcode and execute associated function.
    // @dev The function iterates through the provided instructions and executes each of them
    //      whilst also performing safety checks and updating the pc counter after each instruction execution
    // @param instructions The instruction set.
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func decode_and_execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(instructions: felt*, ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Retrieve the current program counter.
        let pc = ctx.program_counter;

        // Revert if pc < 0
        with_attr error_message("Kakarot: InvalidCodeOffset") {
            assert_nn(pc);
        }

        local opcode;

        let is_pc_le_code_len = is_le_felt(ctx.call_context.code_len, pc);

        if (is_pc_le_code_len == 1) {
            assert opcode = 0;
        } else {
            assert opcode = [ctx.call_context.code + pc];
        }

        // move program counter + 1 after opcode is read
        let ctx = ExecutionContext.increment_program_counter(self=ctx, inc_value=1);

        // Revert if opcode does not exist
        with_attr error_message("Kakarot: UnknownOpcode {opcode}") {
            // Read opcode in instruction set
            let function_codeoffset_felt = instructions[opcode];
            let function_codeoffset = cast(function_codeoffset_felt, codeoffset);
            let (function_ptr) = get_label_location(function_codeoffset);
        }

        // Prepare implicit arguments
        let implicit_args_len = decode_and_execute.ImplicitArgs.SIZE;
        tempvar implicit_args = new decode_and_execute.ImplicitArgs(syscall_ptr, pedersen_ptr, range_check_ptr, bitwise_ptr);

        // Build arguments array
        let (args_len: felt, args: felt*) = prepare_arguments(
            ctx=ctx, implicit_args_len=implicit_args_len, implicit_args=implicit_args
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
        let bitwise_ptr = implicit_args.bitwise_ptr;

        // Get actual return value from ap
        return cast([ap_val - 1], model.ExecutionContext*);
    }

    // @notice Add an instruction in the passed instructions set
    // @param instructions the instruction set
    // @param opcode The opcode value
    // @param function the function to execute for the specified opcode
    func add_instruction(instructions: felt*, opcode: felt, function: codeoffset) {
        assert [instructions + opcode] = cast(function, felt);
        return ();
    }

    // @notice 0x00 - STOP
    // @dev Halts execution
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_stop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = ExecutionContext.stop(ctx_ptr);
        return ctx;
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
    func generate_instructions() -> felt* {
        alloc_locals;
        // Init instructions
        let (instructions: felt*) = alloc();

        // Add instructions

        // Add 0s: Stop and Arithmetic Operations
        // 0x00 - STOP
        add_instruction(instructions=instructions, opcode=0, function=exec_stop);
        // 0x01 - ADD
        add_instruction(
            instructions=instructions, opcode=1, function=ArithmeticOperations.exec_add
        );
        // 0x02 - MUL
        add_instruction(
            instructions=instructions, opcode=2, function=ArithmeticOperations.exec_mul
        );
        // 0x03 - SUB
        add_instruction(
            instructions=instructions, opcode=3, function=ArithmeticOperations.exec_sub
        );
        // 0x04 - DIV
        add_instruction(
            instructions=instructions, opcode=4, function=ArithmeticOperations.exec_div
        );
        // 0x05 - SDIV
        add_instruction(
            instructions=instructions, opcode=5, function=ArithmeticOperations.exec_sdiv
        );
        // 0x06 - MOD
        add_instruction(
            instructions=instructions, opcode=6, function=ArithmeticOperations.exec_mod
        );
        // 0x07 - SMOD
        add_instruction(
            instructions=instructions, opcode=7, function=ArithmeticOperations.exec_smod
        );
        // 0x08 - ADDMOD
        add_instruction(
            instructions=instructions, opcode=8, function=ArithmeticOperations.exec_addmod
        );
        // 0x09 - MULMOD
        add_instruction(
            instructions=instructions, opcode=9, function=ArithmeticOperations.exec_mulmod
        );
        // 0x0A - EXP
        add_instruction(
            instructions=instructions, opcode=0xA, function=ArithmeticOperations.exec_exp
        );
        // 0x0B - SIGNEXTEND
        add_instruction(
            instructions=instructions, opcode=0xB, function=ArithmeticOperations.exec_signextend
        );

        // Comparison & bitwise logic operations
        // 0x10 - LT
        add_instruction(
            instructions=instructions, opcode=0x10, function=ComparisonOperations.exec_lt
        );
        // 0x11 - GT
        add_instruction(
            instructions=instructions, opcode=0x11, function=ComparisonOperations.exec_gt
        );
        // 0x12 - SLT
        add_instruction(
            instructions=instructions, opcode=0x12, function=ComparisonOperations.exec_slt
        );
        // 0x13 - SGT
        add_instruction(
            instructions=instructions, opcode=0x13, function=ComparisonOperations.exec_sgt
        );
        // 0x14 - EQ
        add_instruction(
            instructions=instructions, opcode=0x14, function=ComparisonOperations.exec_eq
        );
        // 0x15 - ISZERO
        add_instruction(
            instructions=instructions, opcode=0x15, function=ComparisonOperations.exec_iszero
        );
        // 0x16 - AND
        add_instruction(
            instructions=instructions, opcode=0x16, function=ComparisonOperations.exec_and
        );
        // 0x17 - OR
        add_instruction(
            instructions=instructions, opcode=0x17, function=ComparisonOperations.exec_or
        );
        // 0x18 - XOR
        add_instruction(
            instructions=instructions, opcode=0x18, function=ComparisonOperations.exec_xor
        );
        // 0x19 - NOT
        add_instruction(
            instructions=instructions, opcode=0x19, function=ComparisonOperations.exec_not
        );
        // 0x1A - BYTE
        add_instruction(
            instructions=instructions, opcode=0x1A, function=ComparisonOperations.exec_byte
        );
        // 0x1B - SHL
        add_instruction(
            instructions=instructions, opcode=0x1B, function=ComparisonOperations.exec_shl
        );
        // 0x1C - SHR
        add_instruction(
            instructions=instructions, opcode=0x1C, function=ComparisonOperations.exec_shr
        );
        // 0x1D - SAR
        add_instruction(
            instructions=instructions, opcode=0x1D, function=ComparisonOperations.exec_sar
        );

        // 0x20 - SHA3
        add_instruction(instructions=instructions, opcode=0x20, function=Sha3.exec_sha3);

        // Environment Information
        // 0x31 - BALANCE
        add_instruction(
            instructions=instructions, opcode=0x31, function=EnvironmentalInformation.exec_balance
        );
        // 0x32 - ORIGIN
        add_instruction(
            instructions=instructions, opcode=0x32, function=EnvironmentalInformation.exec_origin
        );
        // 0x33 - CALLER
        add_instruction(
            instructions=instructions, opcode=0x33, function=EnvironmentalInformation.exec_caller
        );
        // 0x33 - CALLVALUE
        add_instruction(
            instructions=instructions, opcode=0x34, function=EnvironmentalInformation.exec_callvalue
        );
        // 0x35 - CALLDATALOAD
        add_instruction(
            instructions=instructions,
            opcode=0x35,
            function=EnvironmentalInformation.exec_calldataload,
        );
        // 0x36 - CALLDATASIZE
        add_instruction(
            instructions=instructions,
            opcode=0x36,
            function=EnvironmentalInformation.exec_calldatasize,
        );
        // 0x37 - CALLDATACOPY
        add_instruction(
            instructions=instructions,
            opcode=0x37,
            function=EnvironmentalInformation.exec_calldatacopy,
        );
        // 0x38 - CODESIZE
        add_instruction(
            instructions=instructions, opcode=0x38, function=EnvironmentalInformation.exec_codesize
        );
        // 0x39 - CODECOPY
        add_instruction(instructions, opcode=0x39, function=EnvironmentalInformation.exec_codecopy);
        // 0x3d - RETURNDATASIZE
        add_instruction(
            instructions=instructions,
            opcode=0x3d,
            function=EnvironmentalInformation.exec_returndatasize,
        );
        // 0x3e - RETURNDATACOPY
        add_instruction(instructions, 0x3e, EnvironmentalInformation.exec_returndatacopy);

        // Block Information
        // 0x41 - COINBASE
        add_instruction(
            instructions=instructions, opcode=0x41, function=BlockInformation.exec_coinbase
        );
        // 0x42 - TIMESTAMP
        add_instruction(
            instructions=instructions, opcode=0x42, function=BlockInformation.exec_timestamp
        );
        // 0x43 - NUMBER
        add_instruction(
            instructions=instructions, opcode=0x43, function=BlockInformation.exec_number
        );
        // 0x44 - DIFFICULTY
        add_instruction(
            instructions=instructions, opcode=0x44, function=BlockInformation.exec_difficulty
        );
        // 0x45 - GASLIMIT
        add_instruction(
            instructions=instructions, opcode=0x45, function=BlockInformation.exec_gaslimit
        );
        // 0x46 - CHAINID
        add_instruction(
            instructions=instructions, opcode=0x46, function=BlockInformation.exec_chainid
        );
        // 0x47 - SELFBALANCE
        add_instruction(
            instructions=instructions, opcode=0x47, function=BlockInformation.exec_selfbalance
        );
        // 0x48 - BASEFEE
        add_instruction(
            instructions=instructions, opcode=0x48, function=BlockInformation.exec_basefee
        );

        // Stack Memory Storage and Flow Operations

        // 0x50 - POP
        add_instruction(instructions=instructions, opcode=0x50, function=MemoryOperations.exec_pop);
        // 0x51 - MLOAD
        add_instruction(
            instructions=instructions, opcode=0x51, function=MemoryOperations.exec_mload
        );
        // 0x52 - MSTORE
        add_instruction(
            instructions=instructions, opcode=0x52, function=MemoryOperations.exec_mstore
        );
        // 0x53 - MSTORE8
        add_instruction(
            instructions=instructions, opcode=0x53, function=MemoryOperations.exec_mstore8
        );
        // 0x54 - SLOAD
        add_instruction(
            instructions=instructions, opcode=0x54, function=MemoryOperations.exec_sload
        );
        // 0x55 - SSTORE
        add_instruction(
            instructions=instructions, opcode=0x55, function=MemoryOperations.exec_sstore
        );
        // 0x56 - JUMP
        add_instruction(
            instructions=instructions, opcode=0x56, function=MemoryOperations.exec_jump
        );
        // 0x57 - JUMPI
        add_instruction(
            instructions=instructions, opcode=0x57, function=MemoryOperations.exec_jumpi
        );
        // 0x58 - PC
        add_instruction(instructions=instructions, opcode=0x58, function=MemoryOperations.exec_pc);
        // 0x59 - MSIZE
        add_instruction(
            instructions=instructions, opcode=0x59, function=MemoryOperations.exec_msize
        );
        // 0x5A - GAS
        add_instruction(instructions, opcode=0x5A, function=MemoryOperations.exec_gas);
        // 0x5b - JUMPDEST
        add_instruction(
            instructions=instructions, opcode=0x5b, function=MemoryOperations.exec_jumpdest
        );

        // Add 6s: Push operations
        add_instruction(instructions=instructions, opcode=0x60, function=PushOperations.exec_push1);
        add_instruction(instructions=instructions, opcode=0x61, function=PushOperations.exec_push2);
        add_instruction(instructions=instructions, opcode=0x62, function=PushOperations.exec_push3);
        add_instruction(instructions=instructions, opcode=0x63, function=PushOperations.exec_push4);
        add_instruction(instructions=instructions, opcode=0x64, function=PushOperations.exec_push5);
        add_instruction(instructions=instructions, opcode=0x65, function=PushOperations.exec_push6);
        add_instruction(instructions=instructions, opcode=0x66, function=PushOperations.exec_push7);
        add_instruction(instructions=instructions, opcode=0x67, function=PushOperations.exec_push8);
        add_instruction(instructions=instructions, opcode=0x68, function=PushOperations.exec_push9);
        add_instruction(
            instructions=instructions, opcode=0x69, function=PushOperations.exec_push10
        );
        add_instruction(
            instructions=instructions, opcode=0x6a, function=PushOperations.exec_push11
        );
        add_instruction(
            instructions=instructions, opcode=0x6b, function=PushOperations.exec_push12
        );
        add_instruction(
            instructions=instructions, opcode=0x6c, function=PushOperations.exec_push13
        );
        add_instruction(
            instructions=instructions, opcode=0x6d, function=PushOperations.exec_push14
        );
        add_instruction(
            instructions=instructions, opcode=0x6e, function=PushOperations.exec_push15
        );
        add_instruction(
            instructions=instructions, opcode=0x6f, function=PushOperations.exec_push16
        );
        add_instruction(
            instructions=instructions, opcode=0x70, function=PushOperations.exec_push17
        );
        add_instruction(
            instructions=instructions, opcode=0x71, function=PushOperations.exec_push18
        );
        add_instruction(
            instructions=instructions, opcode=0x72, function=PushOperations.exec_push19
        );
        add_instruction(
            instructions=instructions, opcode=0x73, function=PushOperations.exec_push20
        );
        add_instruction(
            instructions=instructions, opcode=0x74, function=PushOperations.exec_push21
        );
        add_instruction(
            instructions=instructions, opcode=0x75, function=PushOperations.exec_push22
        );
        add_instruction(
            instructions=instructions, opcode=0x76, function=PushOperations.exec_push23
        );
        add_instruction(
            instructions=instructions, opcode=0x77, function=PushOperations.exec_push24
        );
        add_instruction(
            instructions=instructions, opcode=0x78, function=PushOperations.exec_push25
        );
        add_instruction(
            instructions=instructions, opcode=0x79, function=PushOperations.exec_push26
        );
        add_instruction(
            instructions=instructions, opcode=0x7a, function=PushOperations.exec_push27
        );
        add_instruction(
            instructions=instructions, opcode=0x7b, function=PushOperations.exec_push28
        );
        add_instruction(
            instructions=instructions, opcode=0x7c, function=PushOperations.exec_push29
        );
        add_instruction(
            instructions=instructions, opcode=0x7d, function=PushOperations.exec_push30
        );
        add_instruction(
            instructions=instructions, opcode=0x7e, function=PushOperations.exec_push31
        );
        add_instruction(
            instructions=instructions, opcode=0x7f, function=PushOperations.exec_push32
        );

        // Add 8s: Duplication operations
        add_instruction(
            instructions=instructions, opcode=0x80, function=DuplicationOperations.exec_dup1
        );
        add_instruction(
            instructions=instructions, opcode=0x81, function=DuplicationOperations.exec_dup2
        );
        add_instruction(
            instructions=instructions, opcode=0x82, function=DuplicationOperations.exec_dup3
        );
        add_instruction(
            instructions=instructions, opcode=0x83, function=DuplicationOperations.exec_dup4
        );
        add_instruction(
            instructions=instructions, opcode=0x84, function=DuplicationOperations.exec_dup5
        );
        add_instruction(
            instructions=instructions, opcode=0x85, function=DuplicationOperations.exec_dup6
        );
        add_instruction(
            instructions=instructions, opcode=0x86, function=DuplicationOperations.exec_dup7
        );
        add_instruction(
            instructions=instructions, opcode=0x87, function=DuplicationOperations.exec_dup8
        );
        add_instruction(
            instructions=instructions, opcode=0x88, function=DuplicationOperations.exec_dup9
        );
        add_instruction(
            instructions=instructions, opcode=0x89, function=DuplicationOperations.exec_dup10
        );
        add_instruction(
            instructions=instructions, opcode=0x8a, function=DuplicationOperations.exec_dup11
        );
        add_instruction(
            instructions=instructions, opcode=0x8b, function=DuplicationOperations.exec_dup12
        );
        add_instruction(
            instructions=instructions, opcode=0x8c, function=DuplicationOperations.exec_dup13
        );
        add_instruction(
            instructions=instructions, opcode=0x8d, function=DuplicationOperations.exec_dup14
        );
        add_instruction(
            instructions=instructions, opcode=0x8e, function=DuplicationOperations.exec_dup15
        );
        add_instruction(
            instructions=instructions, opcode=0x8f, function=DuplicationOperations.exec_dup16
        );

        // Add 9s: Exchange operations
        add_instruction(
            instructions=instructions, opcode=0x90, function=ExchangeOperations.exec_swap1
        );
        add_instruction(
            instructions=instructions, opcode=0x91, function=ExchangeOperations.exec_swap2
        );
        add_instruction(
            instructions=instructions, opcode=0x92, function=ExchangeOperations.exec_swap3
        );
        add_instruction(
            instructions=instructions, opcode=0x93, function=ExchangeOperations.exec_swap4
        );
        add_instruction(
            instructions=instructions, opcode=0x94, function=ExchangeOperations.exec_swap5
        );
        add_instruction(
            instructions=instructions, opcode=0x95, function=ExchangeOperations.exec_swap6
        );
        add_instruction(
            instructions=instructions, opcode=0x96, function=ExchangeOperations.exec_swap7
        );
        add_instruction(
            instructions=instructions, opcode=0x97, function=ExchangeOperations.exec_swap8
        );
        add_instruction(
            instructions=instructions, opcode=0x98, function=ExchangeOperations.exec_swap9
        );
        add_instruction(
            instructions=instructions, opcode=0x99, function=ExchangeOperations.exec_swap10
        );
        add_instruction(
            instructions=instructions, opcode=0x9a, function=ExchangeOperations.exec_swap11
        );
        add_instruction(
            instructions=instructions, opcode=0x9b, function=ExchangeOperations.exec_swap12
        );
        add_instruction(
            instructions=instructions, opcode=0x9c, function=ExchangeOperations.exec_swap13
        );
        add_instruction(
            instructions=instructions, opcode=0x9d, function=ExchangeOperations.exec_swap14
        );
        add_instruction(
            instructions=instructions, opcode=0x9e, function=ExchangeOperations.exec_swap15
        );
        add_instruction(
            instructions=instructions, opcode=0x9f, function=ExchangeOperations.exec_swap16
        );

        // Add as: Log operations
        add_instruction(
            instructions=instructions, opcode=0xa0, function=LoggingOperations.exec_log_0
        );
        add_instruction(
            instructions=instructions, opcode=0xa1, function=LoggingOperations.exec_log_1
        );
        add_instruction(
            instructions=instructions, opcode=0xa2, function=LoggingOperations.exec_log_2
        );
        add_instruction(
            instructions=instructions, opcode=0xa3, function=LoggingOperations.exec_log_3
        );
        add_instruction(
            instructions=instructions, opcode=0xa4, function=LoggingOperations.exec_log_4
        );

        // Add fs: System operations
        add_instruction(
            instructions=instructions, opcode=0xfe, function=SystemOperations.exec_invalid
        );
        // 0xF3 - RETURN
        add_instruction(instructions, 0xf3, SystemOperations.exec_return);
        return instructions;
    }
}
