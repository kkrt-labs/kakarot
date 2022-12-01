// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.registers import get_ap
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.instructions.push_operations import PushOperations
from kakarot.instructions.stop_and_arithmetic_operations import StopAndArithmeticOperations
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
    // @dev The function uses an internal jump table to execute the corresponding opcode
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func decode_and_execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Retrieve the current program counter.
        let pc = ctx.program_counter;
        local opcode;

        let is_pc_ge_code_len = is_le(ctx.call_context.bytecode_len, pc);

        if (is_pc_ge_code_len != FALSE) {
            assert opcode = 0;
        } else {
            assert opcode = [ctx.call_context.bytecode + pc];
        }

        // Compute the corresponding offset in the jump table:
        // count 1 for "next line" and 4 steps per opcode: call, opcode, ret
        tempvar offset = 1 + 3 * opcode;

        // move program counter + 1 after opcode is read
        let ctx = ExecutionContext.increment_program_counter(self=ctx, inc_value=1);

        // Prepare arguments
        [ap] = syscall_ptr, ap++;
        [ap] = pedersen_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = bitwise_ptr, ap++;
        [ap] = ctx, ap++;

        // call opcode
        jmp rel offset;
        call StopAndArithmeticOperations.exec_stop;  // 0x0
        ret;
        call StopAndArithmeticOperations.exec_add;  // 0x1
        ret;
        call StopAndArithmeticOperations.exec_mul;  // 0x2
        ret;
        call StopAndArithmeticOperations.exec_sub;  // 0x3
        ret;
        call StopAndArithmeticOperations.exec_div;  // 0x4
        ret;
        call StopAndArithmeticOperations.exec_sdiv;  // 0x5
        ret;
        call StopAndArithmeticOperations.exec_mod;  // 0x6
        ret;
        call StopAndArithmeticOperations.exec_smod;  // 0x7
        ret;
        call StopAndArithmeticOperations.exec_addmod;  // 0x8
        ret;
        call StopAndArithmeticOperations.exec_mulmod;  // 0x9
        ret;
        call StopAndArithmeticOperations.exec_exp;  // 0xa
        ret;
        call StopAndArithmeticOperations.exec_signextend;  // 0xb
        ret;
        call unknown_opcode;  // 0xc
        ret;
        call unknown_opcode;  // 0xd
        ret;
        call unknown_opcode;  // 0xe
        ret;
        call unknown_opcode;  // 0xf
        ret;
        call ComparisonOperations.exec_lt;  // 0x10
        ret;
        call ComparisonOperations.exec_gt;  // 0x11
        ret;
        call ComparisonOperations.exec_slt;  // 0x12
        ret;
        call ComparisonOperations.exec_sgt;  // 0x13
        ret;
        call ComparisonOperations.exec_eq;  // 0x14
        ret;
        call ComparisonOperations.exec_iszero;  // 0x15
        ret;
        call ComparisonOperations.exec_and;  // 0x16
        ret;
        call ComparisonOperations.exec_or;  // 0x17
        ret;
        call ComparisonOperations.exec_xor;  // 0x18
        ret;
        call ComparisonOperations.exec_not;  // 0x19
        ret;
        call ComparisonOperations.exec_byte;  // 0x1a
        ret;
        call ComparisonOperations.exec_shl;  // 0x1b
        ret;
        call ComparisonOperations.exec_shr;  // 0x1c
        ret;
        call ComparisonOperations.exec_sar;  // 0x1d
        ret;
        call unknown_opcode;  // 0x1e
        ret;
        call unknown_opcode;  // 0x1f
        ret;
        call Sha3.exec_sha3;  // 0x20
        ret;
        call unknown_opcode;  // 0x21
        ret;
        call unknown_opcode;  // 0x22
        ret;
        call unknown_opcode;  // 0x23
        ret;
        call unknown_opcode;  // 0x24
        ret;
        call unknown_opcode;  // 0x25
        ret;
        call unknown_opcode;  // 0x26
        ret;
        call unknown_opcode;  // 0x27
        ret;
        call unknown_opcode;  // 0x28
        ret;
        call unknown_opcode;  // 0x29
        ret;
        call unknown_opcode;  // 0x2a
        ret;
        call unknown_opcode;  // 0x2b
        ret;
        call unknown_opcode;  // 0x2c
        ret;
        call unknown_opcode;  // 0x2d
        ret;
        call unknown_opcode;  // 0x2e
        ret;
        call unknown_opcode;  // 0x2f
        ret;
        call EnvironmentalInformation.exec_address;  // 0x30
        ret;
        call EnvironmentalInformation.exec_balance;  // 0x31
        ret;
        call EnvironmentalInformation.exec_origin;  // 0x32
        ret;
        call EnvironmentalInformation.exec_caller;  // 0x33
        ret;
        call EnvironmentalInformation.exec_callvalue;  // 0x34
        ret;
        call EnvironmentalInformation.exec_calldataload;  // 0x35
        ret;
        call EnvironmentalInformation.exec_calldatasize;  // 0x36
        ret;
        call EnvironmentalInformation.exec_calldatacopy;  // 0x37
        ret;
        call EnvironmentalInformation.exec_codesize;  // 0x38
        ret;
        call EnvironmentalInformation.exec_codecopy;  // 0x39
        ret;
        call not_implemented_opcode;  // 0x3a
        ret;
        call not_implemented_opcode;  // 0x3b
        ret;
        call not_implemented_opcode;  // 0x3c
        ret;
        call EnvironmentalInformation.exec_returndatasize;  // 0x3d
        ret;
        call EnvironmentalInformation.exec_returndatacopy;  // 0x3e
        ret;
        call not_implemented_opcode;  // 0x3f
        ret;
        call not_implemented_opcode;  // 0x40
        ret;
        call BlockInformation.exec_coinbase;  // 0x41
        ret;
        call BlockInformation.exec_timestamp;  // 0x42
        ret;
        call BlockInformation.exec_number;  // 0x43
        ret;
        call BlockInformation.exec_difficulty;  // 0x44
        ret;
        call BlockInformation.exec_gaslimit;  // 0x45
        ret;
        call BlockInformation.exec_chainid;  // 0x46
        ret;
        call BlockInformation.exec_selfbalance;  // 0x47
        ret;
        call BlockInformation.exec_basefee;  // 0x48
        ret;
        call unknown_opcode;  // 0x49
        ret;
        call unknown_opcode;  // 0x4a
        ret;
        call unknown_opcode;  // 0x4b
        ret;
        call unknown_opcode;  // 0x4c
        ret;
        call unknown_opcode;  // 0x4d
        ret;
        call unknown_opcode;  // 0x4e
        ret;
        call unknown_opcode;  // 0x4f
        ret;
        call MemoryOperations.exec_pop;  // 0x50
        ret;
        call MemoryOperations.exec_mload;  // 0x51
        ret;
        call MemoryOperations.exec_mstore;  // 0x52
        ret;
        call MemoryOperations.exec_mstore8;  // 0x53
        ret;
        call MemoryOperations.exec_sload;  // 0x54
        ret;
        call MemoryOperations.exec_sstore;  // 0x55
        ret;
        call MemoryOperations.exec_jump;  // 0x56
        ret;
        call MemoryOperations.exec_jumpi;  // 0x57
        ret;
        call MemoryOperations.exec_pc;  // 0x58
        ret;
        call MemoryOperations.exec_msize;  // 0x59
        ret;
        call MemoryOperations.exec_gas;  // 0x5a
        ret;
        call MemoryOperations.exec_jumpdest;  // 0x5b
        ret;
        call unknown_opcode;  // 0x5c
        ret;
        call unknown_opcode;  // 0x5d
        ret;
        call unknown_opcode;  // 0x5e
        ret;
        call unknown_opcode;  // 0x5f
        ret;
        call PushOperations.exec_push1;  // 0x60
        ret;
        call PushOperations.exec_push2;  // 0x61
        ret;
        call PushOperations.exec_push3;  // 0x62
        ret;
        call PushOperations.exec_push4;  // 0x63
        ret;
        call PushOperations.exec_push5;  // 0x64
        ret;
        call PushOperations.exec_push6;  // 0x65
        ret;
        call PushOperations.exec_push7;  // 0x66
        ret;
        call PushOperations.exec_push8;  // 0x67
        ret;
        call PushOperations.exec_push9;  // 0x68
        ret;
        call PushOperations.exec_push10;  // 0x69
        ret;
        call PushOperations.exec_push11;  // 0x6a
        ret;
        call PushOperations.exec_push12;  // 0x6b
        ret;
        call PushOperations.exec_push13;  // 0x6c
        ret;
        call PushOperations.exec_push14;  // 0x6d
        ret;
        call PushOperations.exec_push15;  // 0x6e
        ret;
        call PushOperations.exec_push16;  // 0x6f
        ret;
        call PushOperations.exec_push17;  // 0x70
        ret;
        call PushOperations.exec_push18;  // 0x71
        ret;
        call PushOperations.exec_push19;  // 0x72
        ret;
        call PushOperations.exec_push20;  // 0x73
        ret;
        call PushOperations.exec_push21;  // 0x74
        ret;
        call PushOperations.exec_push22;  // 0x75
        ret;
        call PushOperations.exec_push23;  // 0x76
        ret;
        call PushOperations.exec_push24;  // 0x77
        ret;
        call PushOperations.exec_push25;  // 0x78
        ret;
        call PushOperations.exec_push26;  // 0x79
        ret;
        call PushOperations.exec_push27;  // 0x7a
        ret;
        call PushOperations.exec_push28;  // 0x7b
        ret;
        call PushOperations.exec_push29;  // 0x7c
        ret;
        call PushOperations.exec_push30;  // 0x7d
        ret;
        call PushOperations.exec_push31;  // 0x7e
        ret;
        call PushOperations.exec_push32;  // 0x7f
        ret;
        call DuplicationOperations.exec_dup1;  // 0x80
        ret;
        call DuplicationOperations.exec_dup2;  // 0x81
        ret;
        call DuplicationOperations.exec_dup3;  // 0x82
        ret;
        call DuplicationOperations.exec_dup4;  // 0x83
        ret;
        call DuplicationOperations.exec_dup5;  // 0x84
        ret;
        call DuplicationOperations.exec_dup6;  // 0x85
        ret;
        call DuplicationOperations.exec_dup7;  // 0x86
        ret;
        call DuplicationOperations.exec_dup8;  // 0x87
        ret;
        call DuplicationOperations.exec_dup9;  // 0x88
        ret;
        call DuplicationOperations.exec_dup10;  // 0x89
        ret;
        call DuplicationOperations.exec_dup11;  // 0x8a
        ret;
        call DuplicationOperations.exec_dup12;  // 0x8b
        ret;
        call DuplicationOperations.exec_dup13;  // 0x8c
        ret;
        call DuplicationOperations.exec_dup14;  // 0x8d
        ret;
        call DuplicationOperations.exec_dup15;  // 0x8e
        ret;
        call DuplicationOperations.exec_dup16;  // 0x8f
        ret;
        call ExchangeOperations.exec_swap1;  // 0x90
        ret;
        call ExchangeOperations.exec_swap2;  // 0x91
        ret;
        call ExchangeOperations.exec_swap3;  // 0x92
        ret;
        call ExchangeOperations.exec_swap4;  // 0x93
        ret;
        call ExchangeOperations.exec_swap5;  // 0x94
        ret;
        call ExchangeOperations.exec_swap6;  // 0x95
        ret;
        call ExchangeOperations.exec_swap7;  // 0x96
        ret;
        call ExchangeOperations.exec_swap8;  // 0x97
        ret;
        call ExchangeOperations.exec_swap9;  // 0x98
        ret;
        call ExchangeOperations.exec_swap10;  // 0x99
        ret;
        call ExchangeOperations.exec_swap11;  // 0x9a
        ret;
        call ExchangeOperations.exec_swap12;  // 0x9b
        ret;
        call ExchangeOperations.exec_swap13;  // 0x9c
        ret;
        call ExchangeOperations.exec_swap14;  // 0x9d
        ret;
        call ExchangeOperations.exec_swap15;  // 0x9e
        ret;
        call ExchangeOperations.exec_swap16;  // 0x9f
        ret;
        call LoggingOperations.exec_log_0;  // 0xa0
        ret;
        call LoggingOperations.exec_log_1;  // 0xa1
        ret;
        call LoggingOperations.exec_log_2;  // 0xa2
        ret;
        call LoggingOperations.exec_log_3;  // 0xa3
        ret;
        call LoggingOperations.exec_log_4;  // 0xa4
        ret;
        call unknown_opcode;  // 0xa5
        ret;
        call unknown_opcode;  // 0xa6
        ret;
        call unknown_opcode;  // 0xa7
        ret;
        call unknown_opcode;  // 0xa8
        ret;
        call unknown_opcode;  // 0xa9
        ret;
        call unknown_opcode;  // 0xaa
        ret;
        call unknown_opcode;  // 0xab
        ret;
        call unknown_opcode;  // 0xac
        ret;
        call unknown_opcode;  // 0xad
        ret;
        call unknown_opcode;  // 0xae
        ret;
        call unknown_opcode;  // 0xaf
        ret;
        call unknown_opcode;  // 0xb0
        ret;
        call unknown_opcode;  // 0xb1
        ret;
        call unknown_opcode;  // 0xb2
        ret;
        call unknown_opcode;  // 0xb3
        ret;
        call unknown_opcode;  // 0xb4
        ret;
        call unknown_opcode;  // 0xb5
        ret;
        call unknown_opcode;  // 0xb6
        ret;
        call unknown_opcode;  // 0xb7
        ret;
        call unknown_opcode;  // 0xb8
        ret;
        call unknown_opcode;  // 0xb9
        ret;
        call unknown_opcode;  // 0xba
        ret;
        call unknown_opcode;  // 0xbb
        ret;
        call unknown_opcode;  // 0xbc
        ret;
        call unknown_opcode;  // 0xbd
        ret;
        call unknown_opcode;  // 0xbe
        ret;
        call unknown_opcode;  // 0xbf
        ret;
        call unknown_opcode;  // 0xc0
        ret;
        call unknown_opcode;  // 0xc1
        ret;
        call unknown_opcode;  // 0xc2
        ret;
        call unknown_opcode;  // 0xc3
        ret;
        call unknown_opcode;  // 0xc4
        ret;
        call unknown_opcode;  // 0xc5
        ret;
        call unknown_opcode;  // 0xc6
        ret;
        call unknown_opcode;  // 0xc7
        ret;
        call unknown_opcode;  // 0xc8
        ret;
        call unknown_opcode;  // 0xc9
        ret;
        call unknown_opcode;  // 0xca
        ret;
        call unknown_opcode;  // 0xcb
        ret;
        call unknown_opcode;  // 0xcc
        ret;
        call unknown_opcode;  // 0xcd
        ret;
        call unknown_opcode;  // 0xce
        ret;
        call unknown_opcode;  // 0xcf
        ret;
        call unknown_opcode;  // 0xd0
        ret;
        call unknown_opcode;  // 0xd1
        ret;
        call unknown_opcode;  // 0xd2
        ret;
        call unknown_opcode;  // 0xd3
        ret;
        call unknown_opcode;  // 0xd4
        ret;
        call unknown_opcode;  // 0xd5
        ret;
        call unknown_opcode;  // 0xd6
        ret;
        call unknown_opcode;  // 0xd7
        ret;
        call unknown_opcode;  // 0xd8
        ret;
        call unknown_opcode;  // 0xd9
        ret;
        call unknown_opcode;  // 0xda
        ret;
        call unknown_opcode;  // 0xdb
        ret;
        call unknown_opcode;  // 0xdc
        ret;
        call unknown_opcode;  // 0xdd
        ret;
        call unknown_opcode;  // 0xde
        ret;
        call unknown_opcode;  // 0xdf
        ret;
        call unknown_opcode;  // 0xe0
        ret;
        call unknown_opcode;  // 0xe1
        ret;
        call unknown_opcode;  // 0xe2
        ret;
        call unknown_opcode;  // 0xe3
        ret;
        call unknown_opcode;  // 0xe4
        ret;
        call unknown_opcode;  // 0xe5
        ret;
        call unknown_opcode;  // 0xe6
        ret;
        call unknown_opcode;  // 0xe7
        ret;
        call unknown_opcode;  // 0xe8
        ret;
        call unknown_opcode;  // 0xe9
        ret;
        call unknown_opcode;  // 0xea
        ret;
        call unknown_opcode;  // 0xeb
        ret;
        call unknown_opcode;  // 0xec
        ret;
        call unknown_opcode;  // 0xed
        ret;
        call unknown_opcode;  // 0xee
        ret;
        call unknown_opcode;  // 0xef
        ret;
        call not_implemented_opcode;  // 0xf0
        ret;
        call not_implemented_opcode;  // 0xf1
        ret;
        call not_implemented_opcode;  // 0xf2
        ret;
        call SystemOperations.exec_return;  // 0xf3
        ret;
        call unknown_opcode;  // 0xf4
        ret;
        call not_implemented_opcode;  // 0xf5
        ret;
        call unknown_opcode;  // 0xf6
        ret;
        call unknown_opcode;  // 0xf7
        ret;
        call unknown_opcode;  // 0xf8
        ret;
        call unknown_opcode;  // 0xf9
        ret;
        call not_implemented_opcode;  // 0xfa
        ret;
        call unknown_opcode;  // 0xfb
        ret;
        call unknown_opcode;  // 0xfc
        ret;
        call SystemOperations.exec_revert;  // 0xfd
        ret;
        call SystemOperations.exec_invalid;  // 0xfe
        ret;
        call not_implemented_opcode;  // 0xff
        ret;
    }

    // @notice Iteratively decode and execute the bytecode of an ExecutionContext
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        // Decode and execute
        let ctx: model.ExecutionContext* = decode_and_execute(ctx=ctx);

        // Check if execution should be stopped
        let stopped: felt = ExecutionContext.is_stopped(self=ctx);
        let is_parent_root: felt = ExecutionContext.is_root(self=ctx.parent_context);

        // Terminate execution
        if (stopped != FALSE) {
            if (is_parent_root != FALSE) {
                return ctx;
            } else {
                // TODO: success should be taken from ctx but revert is currently just raising so
                // TODO: writing here TRUE: with the current implementation, a reverting sub_context
                // TODO: would break the whole computation, so if it does not, it's TRUE
                // Note: this Stack.push somehow "belongs" the the (static|deletegate)call(code) opcode that
                // triggered the creationg of the currently ending sub context
                let success = Uint256(low=1, high=0);
                local ctx: model.ExecutionContext* = ctx.parent_context;
                let stack = Stack.push(ctx.stack, success);
                let ctx = ExecutionContext.update_stack(ctx, stack);
                return run(ctx=ctx);
            }
        }

        // Continue execution
        return run(ctx=ctx);
    }

    // @notice A placeholder for opcodes that don't exist
    // @dev Halts execution
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func unknown_opcode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) {
        with_attr error_message("Kakarot: UnknownOpcode") {
            assert 0 = 1;
        }
        return ();
    }

    // @notice A placeholder for opcodes that are not implemented yet
    // @dev Halts execution
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func not_implemented_opcode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) {
        with_attr error_message("Kakarot: NotImplementedOpcode") {
            assert 0 = 1;
        }
        return ();
    }
}
