// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_le
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

        if (is_pc_ge_code_len == TRUE) {
            assert opcode = 0;
        } else {
            assert opcode = [ctx.call_context.bytecode + pc];
        }

        // Compute the corresponding offset in the jump table:
        // count 1 for "next line" and 4 steps per opcode: call, opcode, jmp, end
        tempvar offset = 1 + 4 * opcode;

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
        call exec_stop;  // 0x0
        jmp end;
        call ArithmeticOperations.exec_add;  // 0x1
        jmp end;
        call ArithmeticOperations.exec_mul;  // 0x2
        jmp end;
        call ArithmeticOperations.exec_sub;  // 0x3
        jmp end;
        call ArithmeticOperations.exec_div;  // 0x4
        jmp end;
        call ArithmeticOperations.exec_sdiv;  // 0x5
        jmp end;
        call ArithmeticOperations.exec_mod;  // 0x6
        jmp end;
        call ArithmeticOperations.exec_smod;  // 0x7
        jmp end;
        call ArithmeticOperations.exec_addmod;  // 0x8
        jmp end;
        call ArithmeticOperations.exec_mulmod;  // 0x9
        jmp end;
        call ArithmeticOperations.exec_exp;  // 0xa
        jmp end;
        call ArithmeticOperations.exec_signextend;  // 0xb
        jmp end;
        call unknown_opcode;  // 0xc
        jmp end;
        call unknown_opcode;  // 0xd
        jmp end;
        call unknown_opcode;  // 0xe
        jmp end;
        call unknown_opcode;  // 0xf
        jmp end;
        call ComparisonOperations.exec_lt;  // 0x10
        jmp end;
        call ComparisonOperations.exec_gt;  // 0x11
        jmp end;
        call ComparisonOperations.exec_slt;  // 0x12
        jmp end;
        call ComparisonOperations.exec_sgt;  // 0x13
        jmp end;
        call ComparisonOperations.exec_eq;  // 0x14
        jmp end;
        call ComparisonOperations.exec_iszero;  // 0x15
        jmp end;
        call ComparisonOperations.exec_and;  // 0x16
        jmp end;
        call ComparisonOperations.exec_or;  // 0x17
        jmp end;
        call ComparisonOperations.exec_xor;  // 0x18
        jmp end;
        call ComparisonOperations.exec_not;  // 0x19
        jmp end;
        call ComparisonOperations.exec_byte;  // 0x1a
        jmp end;
        call ComparisonOperations.exec_shl;  // 0x1b
        jmp end;
        call ComparisonOperations.exec_shr;  // 0x1c
        jmp end;
        call ComparisonOperations.exec_sar;  // 0x1d
        jmp end;
        call unknown_opcode;  // 0x1e
        jmp end;
        call unknown_opcode;  // 0x1f
        jmp end;
        call Sha3.exec_sha3;  // 0x20
        jmp end;
        call unknown_opcode;  // 0x21
        jmp end;
        call unknown_opcode;  // 0x22
        jmp end;
        call unknown_opcode;  // 0x23
        jmp end;
        call unknown_opcode;  // 0x24
        jmp end;
        call unknown_opcode;  // 0x25
        jmp end;
        call unknown_opcode;  // 0x26
        jmp end;
        call unknown_opcode;  // 0x27
        jmp end;
        call unknown_opcode;  // 0x28
        jmp end;
        call unknown_opcode;  // 0x29
        jmp end;
        call unknown_opcode;  // 0x2a
        jmp end;
        call unknown_opcode;  // 0x2b
        jmp end;
        call unknown_opcode;  // 0x2c
        jmp end;
        call unknown_opcode;  // 0x2d
        jmp end;
        call unknown_opcode;  // 0x2e
        jmp end;
        call unknown_opcode;  // 0x2f
        jmp end;
        call EnvironmentalInformation.exec_address;  // 0x30
        jmp end;
        call EnvironmentalInformation.exec_balance;  // 0x31
        jmp end;
        call EnvironmentalInformation.exec_origin;  // 0x32
        jmp end;
        call EnvironmentalInformation.exec_caller;  // 0x33
        jmp end;
        call EnvironmentalInformation.exec_callvalue;  // 0x34
        jmp end;
        call EnvironmentalInformation.exec_calldataload;  // 0x35
        jmp end;
        call EnvironmentalInformation.exec_calldatasize;  // 0x36
        jmp end;
        call EnvironmentalInformation.exec_calldatacopy;  // 0x37
        jmp end;
        call EnvironmentalInformation.exec_codesize;  // 0x38
        jmp end;
        call EnvironmentalInformation.exec_codecopy;  // 0x39
        jmp end;
        call not_implemented_opcode;  // 0x3a
        jmp end;
        call not_implemented_opcode;  // 0x3b
        jmp end;
        call not_implemented_opcode;  // 0x3c
        jmp end;
        call EnvironmentalInformation.exec_returndatasize;  // 0x3d
        jmp end;
        call EnvironmentalInformation.exec_returndatacopy;  // 0x3e
        jmp end;
        call not_implemented_opcode;  // 0x3f
        jmp end;
        call not_implemented_opcode;  // 0x40
        jmp end;
        call BlockInformation.exec_coinbase;  // 0x41
        jmp end;
        call BlockInformation.exec_timestamp;  // 0x42
        jmp end;
        call BlockInformation.exec_number;  // 0x43
        jmp end;
        call BlockInformation.exec_difficulty;  // 0x44
        jmp end;
        call BlockInformation.exec_gaslimit;  // 0x45
        jmp end;
        call BlockInformation.exec_chainid;  // 0x46
        jmp end;
        call BlockInformation.exec_selfbalance;  // 0x47
        jmp end;
        call BlockInformation.exec_basefee;  // 0x48
        jmp end;
        call unknown_opcode;  // 0x49
        jmp end;
        call unknown_opcode;  // 0x4a
        jmp end;
        call unknown_opcode;  // 0x4b
        jmp end;
        call unknown_opcode;  // 0x4c
        jmp end;
        call unknown_opcode;  // 0x4d
        jmp end;
        call unknown_opcode;  // 0x4e
        jmp end;
        call unknown_opcode;  // 0x4f
        jmp end;
        call MemoryOperations.exec_pop;  // 0x50
        jmp end;
        call MemoryOperations.exec_mload;  // 0x51
        jmp end;
        call MemoryOperations.exec_mstore;  // 0x52
        jmp end;
        call MemoryOperations.exec_mstore8;  // 0x53
        jmp end;
        call MemoryOperations.exec_sload;  // 0x54
        jmp end;
        call MemoryOperations.exec_sstore;  // 0x55
        jmp end;
        call MemoryOperations.exec_jump;  // 0x56
        jmp end;
        call MemoryOperations.exec_jumpi;  // 0x57
        jmp end;
        call MemoryOperations.exec_pc;  // 0x58
        jmp end;
        call MemoryOperations.exec_msize;  // 0x59
        jmp end;
        call MemoryOperations.exec_gas;  // 0x5a
        jmp end;
        call MemoryOperations.exec_jumpdest;  // 0x5b
        jmp end;
        call unknown_opcode;  // 0x5c
        jmp end;
        call unknown_opcode;  // 0x5d
        jmp end;
        call unknown_opcode;  // 0x5e
        jmp end;
        call unknown_opcode;  // 0x5f
        jmp end;
        call PushOperations.exec_push1;  // 0x60
        jmp end;
        call PushOperations.exec_push2;  // 0x61
        jmp end;
        call PushOperations.exec_push3;  // 0x62
        jmp end;
        call PushOperations.exec_push4;  // 0x63
        jmp end;
        call PushOperations.exec_push5;  // 0x64
        jmp end;
        call PushOperations.exec_push6;  // 0x65
        jmp end;
        call PushOperations.exec_push7;  // 0x66
        jmp end;
        call PushOperations.exec_push8;  // 0x67
        jmp end;
        call PushOperations.exec_push9;  // 0x68
        jmp end;
        call PushOperations.exec_push10;  // 0x69
        jmp end;
        call PushOperations.exec_push11;  // 0x6a
        jmp end;
        call PushOperations.exec_push12;  // 0x6b
        jmp end;
        call PushOperations.exec_push13;  // 0x6c
        jmp end;
        call PushOperations.exec_push14;  // 0x6d
        jmp end;
        call PushOperations.exec_push15;  // 0x6e
        jmp end;
        call PushOperations.exec_push16;  // 0x6f
        jmp end;
        call PushOperations.exec_push17;  // 0x70
        jmp end;
        call PushOperations.exec_push18;  // 0x71
        jmp end;
        call PushOperations.exec_push19;  // 0x72
        jmp end;
        call PushOperations.exec_push20;  // 0x73
        jmp end;
        call PushOperations.exec_push21;  // 0x74
        jmp end;
        call PushOperations.exec_push22;  // 0x75
        jmp end;
        call PushOperations.exec_push23;  // 0x76
        jmp end;
        call PushOperations.exec_push24;  // 0x77
        jmp end;
        call PushOperations.exec_push25;  // 0x78
        jmp end;
        call PushOperations.exec_push26;  // 0x79
        jmp end;
        call PushOperations.exec_push27;  // 0x7a
        jmp end;
        call PushOperations.exec_push28;  // 0x7b
        jmp end;
        call PushOperations.exec_push29;  // 0x7c
        jmp end;
        call PushOperations.exec_push30;  // 0x7d
        jmp end;
        call PushOperations.exec_push31;  // 0x7e
        jmp end;
        call PushOperations.exec_push32;  // 0x7f
        jmp end;
        call DuplicationOperations.exec_dup1;  // 0x80
        jmp end;
        call DuplicationOperations.exec_dup2;  // 0x81
        jmp end;
        call DuplicationOperations.exec_dup3;  // 0x82
        jmp end;
        call DuplicationOperations.exec_dup4;  // 0x83
        jmp end;
        call DuplicationOperations.exec_dup5;  // 0x84
        jmp end;
        call DuplicationOperations.exec_dup6;  // 0x85
        jmp end;
        call DuplicationOperations.exec_dup7;  // 0x86
        jmp end;
        call DuplicationOperations.exec_dup8;  // 0x87
        jmp end;
        call DuplicationOperations.exec_dup9;  // 0x88
        jmp end;
        call DuplicationOperations.exec_dup10;  // 0x89
        jmp end;
        call DuplicationOperations.exec_dup11;  // 0x8a
        jmp end;
        call DuplicationOperations.exec_dup12;  // 0x8b
        jmp end;
        call DuplicationOperations.exec_dup13;  // 0x8c
        jmp end;
        call DuplicationOperations.exec_dup14;  // 0x8d
        jmp end;
        call DuplicationOperations.exec_dup15;  // 0x8e
        jmp end;
        call DuplicationOperations.exec_dup16;  // 0x8f
        jmp end;
        call ExchangeOperations.exec_swap1;  // 0x90
        jmp end;
        call ExchangeOperations.exec_swap2;  // 0x91
        jmp end;
        call ExchangeOperations.exec_swap3;  // 0x92
        jmp end;
        call ExchangeOperations.exec_swap4;  // 0x93
        jmp end;
        call ExchangeOperations.exec_swap5;  // 0x94
        jmp end;
        call ExchangeOperations.exec_swap6;  // 0x95
        jmp end;
        call ExchangeOperations.exec_swap7;  // 0x96
        jmp end;
        call ExchangeOperations.exec_swap8;  // 0x97
        jmp end;
        call ExchangeOperations.exec_swap9;  // 0x98
        jmp end;
        call ExchangeOperations.exec_swap10;  // 0x99
        jmp end;
        call ExchangeOperations.exec_swap11;  // 0x9a
        jmp end;
        call ExchangeOperations.exec_swap12;  // 0x9b
        jmp end;
        call ExchangeOperations.exec_swap13;  // 0x9c
        jmp end;
        call ExchangeOperations.exec_swap14;  // 0x9d
        jmp end;
        call ExchangeOperations.exec_swap15;  // 0x9e
        jmp end;
        call ExchangeOperations.exec_swap16;  // 0x9f
        jmp end;
        call LoggingOperations.exec_log_0;  // 0xa0
        jmp end;
        call LoggingOperations.exec_log_1;  // 0xa1
        jmp end;
        call LoggingOperations.exec_log_2;  // 0xa2
        jmp end;
        call LoggingOperations.exec_log_3;  // 0xa3
        jmp end;
        call LoggingOperations.exec_log_4;  // 0xa4
        jmp end;
        call unknown_opcode;  // 0xa5
        jmp end;
        call unknown_opcode;  // 0xa6
        jmp end;
        call unknown_opcode;  // 0xa7
        jmp end;
        call unknown_opcode;  // 0xa8
        jmp end;
        call unknown_opcode;  // 0xa9
        jmp end;
        call unknown_opcode;  // 0xaa
        jmp end;
        call unknown_opcode;  // 0xab
        jmp end;
        call unknown_opcode;  // 0xac
        jmp end;
        call unknown_opcode;  // 0xad
        jmp end;
        call unknown_opcode;  // 0xae
        jmp end;
        call unknown_opcode;  // 0xaf
        jmp end;
        call unknown_opcode;  // 0xb0
        jmp end;
        call unknown_opcode;  // 0xb1
        jmp end;
        call unknown_opcode;  // 0xb2
        jmp end;
        call unknown_opcode;  // 0xb3
        jmp end;
        call unknown_opcode;  // 0xb4
        jmp end;
        call unknown_opcode;  // 0xb5
        jmp end;
        call unknown_opcode;  // 0xb6
        jmp end;
        call unknown_opcode;  // 0xb7
        jmp end;
        call unknown_opcode;  // 0xb8
        jmp end;
        call unknown_opcode;  // 0xb9
        jmp end;
        call unknown_opcode;  // 0xba
        jmp end;
        call unknown_opcode;  // 0xbb
        jmp end;
        call unknown_opcode;  // 0xbc
        jmp end;
        call unknown_opcode;  // 0xbd
        jmp end;
        call unknown_opcode;  // 0xbe
        jmp end;
        call unknown_opcode;  // 0xbf
        jmp end;
        call unknown_opcode;  // 0xc0
        jmp end;
        call unknown_opcode;  // 0xc1
        jmp end;
        call unknown_opcode;  // 0xc2
        jmp end;
        call unknown_opcode;  // 0xc3
        jmp end;
        call unknown_opcode;  // 0xc4
        jmp end;
        call unknown_opcode;  // 0xc5
        jmp end;
        call unknown_opcode;  // 0xc6
        jmp end;
        call unknown_opcode;  // 0xc7
        jmp end;
        call unknown_opcode;  // 0xc8
        jmp end;
        call unknown_opcode;  // 0xc9
        jmp end;
        call unknown_opcode;  // 0xca
        jmp end;
        call unknown_opcode;  // 0xcb
        jmp end;
        call unknown_opcode;  // 0xcc
        jmp end;
        call unknown_opcode;  // 0xcd
        jmp end;
        call unknown_opcode;  // 0xce
        jmp end;
        call unknown_opcode;  // 0xcf
        jmp end;
        call unknown_opcode;  // 0xd0
        jmp end;
        call unknown_opcode;  // 0xd1
        jmp end;
        call unknown_opcode;  // 0xd2
        jmp end;
        call unknown_opcode;  // 0xd3
        jmp end;
        call unknown_opcode;  // 0xd4
        jmp end;
        call unknown_opcode;  // 0xd5
        jmp end;
        call unknown_opcode;  // 0xd6
        jmp end;
        call unknown_opcode;  // 0xd7
        jmp end;
        call unknown_opcode;  // 0xd8
        jmp end;
        call unknown_opcode;  // 0xd9
        jmp end;
        call unknown_opcode;  // 0xda
        jmp end;
        call unknown_opcode;  // 0xdb
        jmp end;
        call unknown_opcode;  // 0xdc
        jmp end;
        call unknown_opcode;  // 0xdd
        jmp end;
        call unknown_opcode;  // 0xde
        jmp end;
        call unknown_opcode;  // 0xdf
        jmp end;
        call unknown_opcode;  // 0xe0
        jmp end;
        call unknown_opcode;  // 0xe1
        jmp end;
        call unknown_opcode;  // 0xe2
        jmp end;
        call unknown_opcode;  // 0xe3
        jmp end;
        call unknown_opcode;  // 0xe4
        jmp end;
        call unknown_opcode;  // 0xe5
        jmp end;
        call unknown_opcode;  // 0xe6
        jmp end;
        call unknown_opcode;  // 0xe7
        jmp end;
        call unknown_opcode;  // 0xe8
        jmp end;
        call unknown_opcode;  // 0xe9
        jmp end;
        call unknown_opcode;  // 0xea
        jmp end;
        call unknown_opcode;  // 0xeb
        jmp end;
        call unknown_opcode;  // 0xec
        jmp end;
        call unknown_opcode;  // 0xed
        jmp end;
        call unknown_opcode;  // 0xee
        jmp end;
        call unknown_opcode;  // 0xef
        jmp end;
        call not_implemented_opcode;  // 0xf0
        jmp end;
        call not_implemented_opcode;  // 0xf1
        jmp end;
        call not_implemented_opcode;  // 0xf2
        jmp end;
        call SystemOperations.exec_return;  // 0xf3
        jmp end;
        call unknown_opcode;  // 0xf4
        jmp end;
        call not_implemented_opcode;  // 0xf5
        jmp end;
        call unknown_opcode;  // 0xf6
        jmp end;
        call unknown_opcode;  // 0xf7
        jmp end;
        call unknown_opcode;  // 0xf8
        jmp end;
        call unknown_opcode;  // 0xf9
        jmp end;
        call not_implemented_opcode;  // 0xfa
        jmp end;
        call unknown_opcode;  // 0xfb
        jmp end;
        call unknown_opcode;  // 0xfc
        jmp end;
        call SystemOperations.exec_revert;  // 0xfd
        jmp end;
        call SystemOperations.exec_invalid;  // 0xfe
        jmp end;
        call not_implemented_opcode;  // 0xff
        jmp end;

        // Retrieve results
        end:
        let syscall_ptr = cast([ap - 5], felt*);
        let pedersen_ptr = cast([ap - 4], HashBuiltin*);
        let range_check_ptr = [ap - 3];
        let bitwise_ptr = cast([ap - 2], BitwiseBuiltin*);
        let ctx = cast([ap - 1], model.ExecutionContext*);

        return ctx;
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

    // @notice A placeholder for opcodes that don't exist
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
}
