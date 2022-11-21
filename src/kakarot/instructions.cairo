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
    // @dev The function uses an internal jump table to execute the corresponding opcode
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func decode_and_execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr: felt,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Retrieve the current program counter.
        let pc = ctx.program_counter;
        local opcode;

        let is_pc_ge_code_len = is_le_felt(ctx.call_context.bytecode_len, pc);

        if (is_pc_ge_code_len == TRUE) {
            assert opcode = 0;
        } else {
            assert opcode = [ctx.call_context.bytecode + pc];
        }
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
        call exec_stop;
        jmp end;
        call ArithmeticOperations.exec_add;
        jmp end;
        call ArithmeticOperations.exec_mul;
        jmp end;
        call ArithmeticOperations.exec_sub;
        jmp end;
        call ArithmeticOperations.exec_div;
        jmp end;
        call ArithmeticOperations.exec_sdiv;
        jmp end;
        call ArithmeticOperations.exec_mod;
        jmp end;
        call ArithmeticOperations.exec_smod;
        jmp end;
        call ArithmeticOperations.exec_addmod;
        jmp end;
        call ArithmeticOperations.exec_mulmod;
        jmp end;
        call ArithmeticOperations.exec_exp;
        jmp end;
        call ArithmeticOperations.exec_signextend;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call ComparisonOperations.exec_lt;
        jmp end;
        call ComparisonOperations.exec_gt;
        jmp end;
        call ComparisonOperations.exec_slt;
        jmp end;
        call ComparisonOperations.exec_sgt;
        jmp end;
        call ComparisonOperations.exec_eq;
        jmp end;
        call ComparisonOperations.exec_iszero;
        jmp end;
        call ComparisonOperations.exec_and;
        jmp end;
        call ComparisonOperations.exec_or;
        jmp end;
        call ComparisonOperations.exec_xor;
        jmp end;
        call ComparisonOperations.exec_not;
        jmp end;
        call ComparisonOperations.exec_byte;
        jmp end;
        call ComparisonOperations.exec_shl;
        jmp end;
        call ComparisonOperations.exec_shr;
        jmp end;
        call ComparisonOperations.exec_sar;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call Sha3.exec_sha3;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call EnvironmentalInformation.exec_address;
        jmp end;
        call EnvironmentalInformation.exec_balance;
        jmp end;
        call EnvironmentalInformation.exec_origin;
        jmp end;
        call EnvironmentalInformation.exec_caller;
        jmp end;
        call EnvironmentalInformation.exec_callvalue;
        jmp end;
        call EnvironmentalInformation.exec_calldataload;
        jmp end;
        call EnvironmentalInformation.exec_calldatasize;
        jmp end;
        call EnvironmentalInformation.exec_calldatacopy;
        jmp end;
        call EnvironmentalInformation.exec_codesize;
        jmp end;
        call EnvironmentalInformation.exec_codecopy;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call EnvironmentalInformation.exec_returndatasize;
        jmp end;
        call EnvironmentalInformation.exec_returndatacopy;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call BlockInformation.exec_coinbase;
        jmp end;
        call BlockInformation.exec_timestamp;
        jmp end;
        call BlockInformation.exec_number;
        jmp end;
        call BlockInformation.exec_difficulty;
        jmp end;
        call BlockInformation.exec_gaslimit;
        jmp end;
        call BlockInformation.exec_chainid;
        jmp end;
        call BlockInformation.exec_selfbalance;
        jmp end;
        call BlockInformation.exec_basefee;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call MemoryOperations.exec_pop;
        jmp end;
        call MemoryOperations.exec_mload;
        jmp end;
        call MemoryOperations.exec_mstore;
        jmp end;
        call MemoryOperations.exec_mstore8;
        jmp end;
        call MemoryOperations.exec_sload;
        jmp end;
        call MemoryOperations.exec_sstore;
        jmp end;
        call MemoryOperations.exec_jump;
        jmp end;
        call MemoryOperations.exec_jumpi;
        jmp end;
        call MemoryOperations.exec_pc;
        jmp end;
        call MemoryOperations.exec_msize;
        jmp end;
        call MemoryOperations.exec_gas;
        jmp end;
        call MemoryOperations.exec_jumpdest;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call PushOperations.exec_push1;
        jmp end;
        call PushOperations.exec_push2;
        jmp end;
        call PushOperations.exec_push3;
        jmp end;
        call PushOperations.exec_push4;
        jmp end;
        call PushOperations.exec_push5;
        jmp end;
        call PushOperations.exec_push6;
        jmp end;
        call PushOperations.exec_push7;
        jmp end;
        call PushOperations.exec_push8;
        jmp end;
        call PushOperations.exec_push9;
        jmp end;
        call PushOperations.exec_push10;
        jmp end;
        call PushOperations.exec_push11;
        jmp end;
        call PushOperations.exec_push12;
        jmp end;
        call PushOperations.exec_push13;
        jmp end;
        call PushOperations.exec_push14;
        jmp end;
        call PushOperations.exec_push15;
        jmp end;
        call PushOperations.exec_push16;
        jmp end;
        call PushOperations.exec_push17;
        jmp end;
        call PushOperations.exec_push18;
        jmp end;
        call PushOperations.exec_push19;
        jmp end;
        call PushOperations.exec_push20;
        jmp end;
        call PushOperations.exec_push21;
        jmp end;
        call PushOperations.exec_push22;
        jmp end;
        call PushOperations.exec_push23;
        jmp end;
        call PushOperations.exec_push24;
        jmp end;
        call PushOperations.exec_push25;
        jmp end;
        call PushOperations.exec_push26;
        jmp end;
        call PushOperations.exec_push27;
        jmp end;
        call PushOperations.exec_push28;
        jmp end;
        call PushOperations.exec_push29;
        jmp end;
        call PushOperations.exec_push30;
        jmp end;
        call PushOperations.exec_push31;
        jmp end;
        call PushOperations.exec_push32;
        jmp end;
        call DuplicationOperations.exec_dup1;
        jmp end;
        call DuplicationOperations.exec_dup2;
        jmp end;
        call DuplicationOperations.exec_dup3;
        jmp end;
        call DuplicationOperations.exec_dup4;
        jmp end;
        call DuplicationOperations.exec_dup5;
        jmp end;
        call DuplicationOperations.exec_dup6;
        jmp end;
        call DuplicationOperations.exec_dup7;
        jmp end;
        call DuplicationOperations.exec_dup8;
        jmp end;
        call DuplicationOperations.exec_dup9;
        jmp end;
        call DuplicationOperations.exec_dup10;
        jmp end;
        call DuplicationOperations.exec_dup11;
        jmp end;
        call DuplicationOperations.exec_dup12;
        jmp end;
        call DuplicationOperations.exec_dup13;
        jmp end;
        call DuplicationOperations.exec_dup14;
        jmp end;
        call DuplicationOperations.exec_dup15;
        jmp end;
        call DuplicationOperations.exec_dup16;
        jmp end;
        call ExchangeOperations.exec_swap1;
        jmp end;
        call ExchangeOperations.exec_swap2;
        jmp end;
        call ExchangeOperations.exec_swap3;
        jmp end;
        call ExchangeOperations.exec_swap4;
        jmp end;
        call ExchangeOperations.exec_swap5;
        jmp end;
        call ExchangeOperations.exec_swap6;
        jmp end;
        call ExchangeOperations.exec_swap7;
        jmp end;
        call ExchangeOperations.exec_swap8;
        jmp end;
        call ExchangeOperations.exec_swap9;
        jmp end;
        call ExchangeOperations.exec_swap10;
        jmp end;
        call ExchangeOperations.exec_swap11;
        jmp end;
        call ExchangeOperations.exec_swap12;
        jmp end;
        call ExchangeOperations.exec_swap13;
        jmp end;
        call ExchangeOperations.exec_swap14;
        jmp end;
        call ExchangeOperations.exec_swap15;
        jmp end;
        call ExchangeOperations.exec_swap16;
        jmp end;
        call LoggingOperations.exec_log_0;
        jmp end;
        call LoggingOperations.exec_log_1;
        jmp end;
        call LoggingOperations.exec_log_2;
        jmp end;
        call LoggingOperations.exec_log_3;
        jmp end;
        call LoggingOperations.exec_log_4;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call SystemOperations.exec_return;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call unknown_opcode;
        jmp end;
        call SystemOperations.exec_invalid;
        jmp end;
        call unknown_opcode;
        jmp end;

        // Retrieve results
        end:
        let syscall_ptr = cast([ap - 5], felt*);
        let pedersen_ptr = cast([ap - 4], HashBuiltin*);
        let range_check_ptr = cast([ap - 3], felt);
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
