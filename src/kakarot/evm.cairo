// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.lang.compiler.lib.registers import get_fp_and_pc

// Internal dependencies
from kakarot.account import Account
from kakarot.constants import opcodes_label, Constants
from kakarot.errors import Errors
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.block_information import BlockInformation
from kakarot.instructions.duplication_operations import DuplicationOperations
from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.instructions.exchange_operations import ExchangeOperations
from kakarot.instructions.logging_operations import LoggingOperations
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.push_operations import PushOperations
from kakarot.instructions.sha3 import Sha3
from kakarot.instructions.stop_and_math_operations import StopAndMathOperations
from kakarot.instructions.system_operations import CallHelper, CreateHelper, SystemOperations
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.precompiles.precompiles import Precompiles
from kakarot.stack import Stack
from kakarot.state import State
from utils.utils import Helpers

// @title EVM instructions processing.
// @notice This file contains functions related to the processing of EVM instructions.
namespace EVM {
    // Summary of the execution. Created upon finalization of the execution.
    struct Summary {
        memory: Memory.Summary*,
        stack: Stack.Summary*,
        return_data: felt*,
        return_data_len: felt,
        gas_used: felt,
        address: model.Address*,
        reverted: felt,
        state: State.Summary*,
        call_context: model.CallContext*,
        program_counter: felt,
    }

    // @notice Decode the current opcode and execute associated function.
    // @dev The function uses an internal jump table to execute the corresponding opcode
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_opcode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get the current opcode number
        let pc = ctx.program_counter;
        local opcode: model.Opcode*;

        let is_pc_ge_code_len = is_le(ctx.call_context.bytecode_len, pc);
        local opcode_number;
        if (is_pc_ge_code_len != FALSE) {
            assert opcode_number = 0;
        } else {
            assert opcode_number = [ctx.call_context.bytecode + pc];
        }

        // Get the corresponding opcode data
        // To cast the codeoffset opcodes_label to a model.Opcode*, we need to use it to offset
        // the current pc. We get the pc from the `get_fp_and_pc` util and assign a codeoffset (pc_label) to it.
        // In short, this boils down to: opcode = pc + offset - pc = offset
        let (_, cairo_pc) = get_fp_and_pc();

        pc_label:
        assert opcode = cast(
            cairo_pc + (opcodes_label - pc_label) + opcode_number * model.Opcode.SIZE, model.Opcode*
        );

        // Check stack over/under flow
        let stack_underflow = is_le(ctx.stack.size, opcode.stack_size_min - 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }
        let stack_overflow = is_le(
            Constants.STACK_MAX_DEPTH, ctx.stack.size + opcode.stack_size_diff + 1
        );
        if (stack_overflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackOverflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // Check static gas
        let out_of_gas = is_le(ctx.call_context.gas_limit, ctx.gas_used + opcode.gas - 1);
        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // Update ctx
        let ctx = ExecutionContext.increment_program_counter(self=ctx, inc_value=1);
        let ctx = ExecutionContext.increment_gas_used(ctx, opcode.gas);

        // Compute the corresponding offset in the jump table:
        // count 1 for "next line" and 3 steps per opcode: call, opcode, ret
        tempvar offset = 1 + 3 * opcode_number;

        // Prepare arguments
        [ap] = syscall_ptr, ap++;
        [ap] = pedersen_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = bitwise_ptr, ap++;
        [ap] = ctx, ap++;

        // call opcode
        jmp rel offset;
        call StopAndMathOperations.exec_stop;  // 0x0
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x1
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x2
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x3
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x4
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x5
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x6
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x7
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x8
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x9
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0xa
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0xb
        ret;
        call unknown_opcode;  // 0xc
        ret;
        call unknown_opcode;  // 0xd
        ret;
        call unknown_opcode;  // 0xe
        ret;
        call unknown_opcode;  // 0xf
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x10
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x11
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x12
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x13
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x14
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x15
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x16
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x17
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x18
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x19
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x1a
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x1b
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x1c
        ret;
        call StopAndMathOperations.exec_math_operation;  // 0x1d
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
        call EnvironmentalInformation.exec_gasprice;  // 0x3a
        ret;
        call EnvironmentalInformation.exec_extcodesize;  // 0x3b
        ret;
        call EnvironmentalInformation.exec_extcodecopy;  // 0x3c
        ret;
        call EnvironmentalInformation.exec_returndatasize;  // 0x3d
        ret;
        call EnvironmentalInformation.exec_returndatacopy;  // 0x3e
        ret;
        call EnvironmentalInformation.exec_extcodehash;  // 0x3f
        ret;
        call BlockInformation.exec_block_information;  // 0x40
        ret;
        call BlockInformation.exec_block_information;  // 0x41
        ret;
        call BlockInformation.exec_block_information;  // 0x42
        ret;
        call BlockInformation.exec_block_information;  // 0x43
        ret;
        call BlockInformation.exec_block_information;  // 0x44
        ret;
        call BlockInformation.exec_block_information;  // 0x45
        ret;
        call BlockInformation.exec_block_information;  // 0x46
        ret;
        call BlockInformation.exec_block_information;  // 0x47
        ret;
        call BlockInformation.exec_block_information;  // 0x48
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
        call PushOperations.exec_push;  // 0x5f
        ret;
        call PushOperations.exec_push;  // 0x60
        ret;
        call PushOperations.exec_push;  // 0x61
        ret;
        call PushOperations.exec_push;  // 0x62
        ret;
        call PushOperations.exec_push;  // 0x63
        ret;
        call PushOperations.exec_push;  // 0x64
        ret;
        call PushOperations.exec_push;  // 0x65
        ret;
        call PushOperations.exec_push;  // 0x66
        ret;
        call PushOperations.exec_push;  // 0x67
        ret;
        call PushOperations.exec_push;  // 0x68
        ret;
        call PushOperations.exec_push;  // 0x69
        ret;
        call PushOperations.exec_push;  // 0x6a
        ret;
        call PushOperations.exec_push;  // 0x6b
        ret;
        call PushOperations.exec_push;  // 0x6c
        ret;
        call PushOperations.exec_push;  // 0x6d
        ret;
        call PushOperations.exec_push;  // 0x6e
        ret;
        call PushOperations.exec_push;  // 0x6f
        ret;
        call PushOperations.exec_push;  // 0x70
        ret;
        call PushOperations.exec_push;  // 0x71
        ret;
        call PushOperations.exec_push;  // 0x72
        ret;
        call PushOperations.exec_push;  // 0x73
        ret;
        call PushOperations.exec_push;  // 0x74
        ret;
        call PushOperations.exec_push;  // 0x75
        ret;
        call PushOperations.exec_push;  // 0x76
        ret;
        call PushOperations.exec_push;  // 0x77
        ret;
        call PushOperations.exec_push;  // 0x78
        ret;
        call PushOperations.exec_push;  // 0x79
        ret;
        call PushOperations.exec_push;  // 0x7a
        ret;
        call PushOperations.exec_push;  // 0x7b
        ret;
        call PushOperations.exec_push;  // 0x7c
        ret;
        call PushOperations.exec_push;  // 0x7d
        ret;
        call PushOperations.exec_push;  // 0x7e
        ret;
        call PushOperations.exec_push;  // 0x7f
        ret;
        call DuplicationOperations.exec_dup;  // 0x80
        ret;
        call DuplicationOperations.exec_dup;  // 0x81
        ret;
        call DuplicationOperations.exec_dup;  // 0x82
        ret;
        call DuplicationOperations.exec_dup;  // 0x83
        ret;
        call DuplicationOperations.exec_dup;  // 0x84
        ret;
        call DuplicationOperations.exec_dup;  // 0x85
        ret;
        call DuplicationOperations.exec_dup;  // 0x86
        ret;
        call DuplicationOperations.exec_dup;  // 0x87
        ret;
        call DuplicationOperations.exec_dup;  // 0x88
        ret;
        call DuplicationOperations.exec_dup;  // 0x89
        ret;
        call DuplicationOperations.exec_dup;  // 0x8a
        ret;
        call DuplicationOperations.exec_dup;  // 0x8b
        ret;
        call DuplicationOperations.exec_dup;  // 0x8c
        ret;
        call DuplicationOperations.exec_dup;  // 0x8d
        ret;
        call DuplicationOperations.exec_dup;  // 0x8e
        ret;
        call DuplicationOperations.exec_dup;  // 0x8f
        ret;
        call ExchangeOperations.exec_swap;  // 0x90
        ret;
        call ExchangeOperations.exec_swap;  // 0x91
        ret;
        call ExchangeOperations.exec_swap;  // 0x92
        ret;
        call ExchangeOperations.exec_swap;  // 0x93
        ret;
        call ExchangeOperations.exec_swap;  // 0x94
        ret;
        call ExchangeOperations.exec_swap;  // 0x95
        ret;
        call ExchangeOperations.exec_swap;  // 0x96
        ret;
        call ExchangeOperations.exec_swap;  // 0x97
        ret;
        call ExchangeOperations.exec_swap;  // 0x98
        ret;
        call ExchangeOperations.exec_swap;  // 0x99
        ret;
        call ExchangeOperations.exec_swap;  // 0x9a
        ret;
        call ExchangeOperations.exec_swap;  // 0x9b
        ret;
        call ExchangeOperations.exec_swap;  // 0x9c
        ret;
        call ExchangeOperations.exec_swap;  // 0x9d
        ret;
        call ExchangeOperations.exec_swap;  // 0x9e
        ret;
        call ExchangeOperations.exec_swap;  // 0x9f
        ret;
        call LoggingOperations.exec_log;  // 0xa0
        ret;
        call LoggingOperations.exec_log;  // 0xa1
        ret;
        call LoggingOperations.exec_log;  // 0xa2
        ret;
        call LoggingOperations.exec_log;  // 0xa3
        ret;
        call LoggingOperations.exec_log;  // 0xa4
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
        call SystemOperations.exec_create;  // 0xf0
        ret;
        call SystemOperations.exec_call;  // 0xf1
        ret;
        call SystemOperations.exec_callcode;  // 0xf2
        ret;
        call SystemOperations.exec_return;  // 0xf3
        ret;
        call SystemOperations.exec_delegatecall;  // 0xf4
        ret;
        call SystemOperations.exec_create2;  // 0xf5
        ret;
        call unknown_opcode;  // 0xf6
        ret;
        call unknown_opcode;  // 0xf7
        ret;
        call unknown_opcode;  // 0xf8
        ret;
        call unknown_opcode;  // 0xf9
        ret;
        call SystemOperations.exec_staticcall;  // 0xfa
        ret;
        call unknown_opcode;  // 0xfb
        ret;
        call unknown_opcode;  // 0xfc
        ret;
        call SystemOperations.exec_revert;  // 0xfd
        ret;
        call SystemOperations.exec_invalid;  // 0xfe
        ret;
        call SystemOperations.exec_selfdestruct;  // 0xff
        ret;
    }

    // @notice Iteratively decode and execute the bytecode of an ExecutionContext
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the updated execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> Summary* {
        alloc_locals;

        if (ctx.stopped != FALSE) {
            let ctx_summary = ExecutionContext.finalize(ctx);
            let is_root: felt = ExecutionContext.is_empty(self=ctx_summary.calling_context);
            if (is_root != FALSE) {
                let evm_summary = finalize(ctx_summary);
                return evm_summary;
            }

            if (ctx_summary.call_context.is_create != 0) {
                let ctx = CreateHelper.finalize_calling_context(ctx_summary);
                return run(ctx);
            } else {
                let ctx = CallHelper.finalize_calling_context(ctx_summary);
                return run(ctx);
            }
        }

        let ctx = exec_opcode(ctx);
        return run(ctx);
    }

    // @notice Run the given bytecode with the given calldata and parameters
    // @param address The target account address
    // @param is_deploy_tx Whether the transaction is a deploy tx or not
    // @param origin The caller EVM address
    // @param bytecode_len The length of the bytecode
    // @param bytecode The bytecode run
    // @param calldata_len The length of the calldata
    // @param calldata The calldata of the execution
    // @param value The value of the execution
    // @param gas_limit The gas limit of the execution
    // @param gas_price The gas price for the execution
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        address: model.Address*,
        is_deploy_tx: felt,
        origin: model.Address*,
        bytecode_len: felt,
        bytecode: felt*,
        calldata_len: felt,
        calldata: felt*,
        value: felt,
        gas_limit: felt,
        gas_price: felt,
    ) -> Summary* {
        alloc_locals;

        // If is_deploy_tx is TRUE, then
        // bytecode is data and data is empty
        // else, bytecode and data are kept as is
        let bytecode_len = calldata_len * is_deploy_tx + bytecode_len * (1 - is_deploy_tx);
        let calldata_len = calldata_len * (1 - is_deploy_tx);
        if (is_deploy_tx != 0) {
            let (empty: felt*) = alloc();
            tempvar bytecode = calldata;
            tempvar calldata = empty;
        } else {
            tempvar bytecode = bytecode;
            tempvar calldata = calldata;
        }

        let root_context = ExecutionContext.init_empty();
        tempvar call_context = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=bytecode_len,
            calldata=calldata,
            calldata_len=calldata_len,
            value=value,
            gas_limit=gas_limit,
            gas_price=gas_price,
            origin=origin,
            calling_context=root_context,
            address=address,
            read_only=FALSE,
            is_create=is_deploy_tx,
        );

        let ctx = ExecutionContext.init(call_context);
        let ctx = ExecutionContext.add_intrinsic_gas_cost(ctx);

        let state = ctx.state;
        // Handle value
        let amount = Helpers.to_uint256(value);
        let transfer = model.Transfer(origin, address, [amount]);
        let (state, success) = State.add_transfer(state, transfer);

        // Check collision
        let (state, account) = State.get_account(state, address);
        let code_or_nonce = Account.has_code_or_nonce(account);
        let is_collision = code_or_nonce * is_deploy_tx;
        // Nonce is set to 1 in case of deploy_tx
        let nonce = account.nonce * (1 - is_deploy_tx) + is_deploy_tx;
        let account = Account.set_nonce(account, nonce);
        let state = State.set_account(state, address, account);

        let ctx = ExecutionContext.update_state(ctx, state);

        if (is_collision != 0) {
            let (revert_reason_len, revert_reason) = Errors.addressCollision();
            tempvar ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
        } else {
            tempvar ctx = ctx;
        }

        if (success == 0) {
            let (revert_reason_len, revert_reason) = Errors.balanceError();
            tempvar ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
        } else {
            tempvar ctx = ctx;
        }

        let summary = run(ctx);
        return summary;
    }

    // @notice A placeholder for opcodes that don't exist
    // @dev Halts execution
    // @param ctx The pointer to the execution context
    func unknown_opcode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let (revert_reason_len, revert_reason) = Errors.unknownOpcode();
        let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
        return ctx;
    }

    // @notice Finalizes a transaction.
    // @param ctx_summary The pointer to the execution context summary.
    // @return Summary The pointer to the transaction Summary.
    func finalize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_summary: ExecutionContext.Summary*
    ) -> Summary* {
        alloc_locals;
        let state_summary = Internals._get_state_summary(ctx_summary);
        tempvar summary: Summary* = new Summary(
            memory=ctx_summary.memory,
            stack=ctx_summary.stack,
            return_data=ctx_summary.return_data,
            return_data_len=ctx_summary.return_data_len,
            gas_used=ctx_summary.gas_used,
            address=ctx_summary.address,
            reverted=ctx_summary.reverted,
            state=state_summary,
            call_context=ctx_summary.call_context,
            program_counter=ctx_summary.program_counter,
        );

        return summary;
    }
}

namespace Internals {
    func _get_state_summary{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_summary: ExecutionContext.Summary*
    ) -> State.Summary* {
        alloc_locals;
        // In case of a deploy tx, we need to store the return_data in the Account
        if (ctx_summary.call_context.is_create != FALSE) {
            let (state, account) = State.get_account(ctx_summary.state, ctx_summary.address);
            let account = Account.set_code(
                account, ctx_summary.return_data_len, ctx_summary.return_data
            );
            let state = State.set_account(state, ctx_summary.address, account);
            tempvar state = state;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            // Else the state is just the returned state of the ExecutionContext
        } else {
            tempvar state = ctx_summary.state;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;

        let state_summary = State.finalize(state);
        return state_summary;
    }
}
