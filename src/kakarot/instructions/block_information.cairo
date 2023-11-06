// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_in_range, is_le
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.lang.compiler.lib.registers import get_fp_and_pc

// Internal dependencies
from kakarot.storages import blockhash_registry_address
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.interfaces.interfaces import IBlockhashRegistry
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.errors import Errors
from utils.utils import Helpers

// @title BlockInformation information opcodes.
// @notice This file contains the functions to execute for block information opcodes.
namespace BlockInformation {
    func exec_block_information{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        local range_check: felt;
        local opcode: model.Opcode*;

        if (ctx.stack.size == Constants.STACK_MAX_DEPTH) {
            let (revert_reason_len, revert_reason) = Errors.stackOverflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter - 1];

        // To cast the codeoffset opcodes_label to a model.Opcode*, we need to use it to offset
        // the current pc. We get the pc from the `get_fp_and_pc` util and assign a codeoffset (pc_label) to it.
        // In short, this boilds down to: opcode = pc + offset - pc = offset
        // The following lines are equivalent but cheaper than `get_label_location`.
        let (_, pc) = get_fp_and_pc();

        pc_label:
        assert opcode = cast(
            pc + (opcodes_label - pc_label) + (opcode_number - 0x40) * model.Opcode.SIZE,
            model.Opcode*,
        );

        let out_of_gas = is_le(ctx.call_context.gas_limit, ctx.gas_used + opcode.gas - 1);
        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }
        assert range_check = range_check_ptr;

        tempvar offset = 2 * (opcode_number - 0x40) + 1;

        jmp rel offset;
        jmp blockhash;
        jmp coinbase;
        jmp timestamp;
        jmp number;
        jmp prevrandao;
        jmp gaslimit;
        jmp chainid;
        jmp selfbalance;
        jmp basefee;

        blockhash:
        let syscall_ptr = cast([fp - 7], felt*);
        let pedersen_ptr = cast([fp - 6], HashBuiltin*);
        let range_check_ptr = [fp];
        let ctx = cast([fp - 3], model.ExecutionContext*);
        let (ctx, result) = Internals.blockhash(ctx);
        jmp end;

        coinbase:
        tempvar syscall_ptr = cast([fp - 7], felt*);
        tempvar pedersen_ptr = cast([fp - 6], HashBuiltin*);
        tempvar range_check_ptr = [fp];
        tempvar ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar result = Uint256(
            0xacdffe0cf08e20ed8ba10ea97a487004, 0x388ca486b82e20cc81965d056b4cdca
        );
        jmp end;

        timestamp:
        let syscall_ptr = cast([fp - 7], felt*);
        let (block_timestamp) = get_block_timestamp();
        tempvar syscall_ptr = cast([ap - 2], felt*);
        tempvar pedersen_ptr = cast([fp - 6], HashBuiltin*);
        tempvar range_check_ptr = [fp];
        tempvar ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar result = Uint256(block_timestamp, 0);
        jmp end;

        number:
        let syscall_ptr = cast([fp - 7], felt*);
        let (block_number) = get_block_number();
        tempvar syscall_ptr = cast([ap - 2], felt*);
        tempvar pedersen_ptr = cast([fp - 6], HashBuiltin*);
        tempvar range_check_ptr = [fp];
        tempvar ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar result = Uint256(block_number, 0);
        jmp end;

        prevrandao:
        tempvar syscall_ptr = cast([fp - 7], felt*);
        tempvar pedersen_ptr = cast([fp - 6], HashBuiltin*);
        tempvar range_check_ptr = [fp];
        tempvar ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar result = Uint256(0, 0);
        jmp end;

        gaslimit:
        let ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar gas_limit = ctx.call_context.gas_limit;
        tempvar syscall_ptr = cast([fp - 7], felt*);
        tempvar pedersen_ptr = cast([fp - 6], HashBuiltin*);
        tempvar range_check_ptr = [fp];
        tempvar ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar result = Uint256(gas_limit, 0);
        jmp end;

        chainid:
        tempvar syscall_ptr = cast([fp - 7], felt*);
        tempvar pedersen_ptr = cast([fp - 6], HashBuiltin*);
        tempvar range_check_ptr = [fp];
        tempvar ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar result = Uint256(Constants.CHAIN_ID, 0);
        jmp end;

        selfbalance:
        let syscall_ptr = cast([fp - 7], felt*);
        let pedersen_ptr = cast([fp - 6], HashBuiltin*);
        let range_check_ptr = [fp];
        let ctx = cast([fp - 3], model.ExecutionContext*);
        let (ctx, result) = Internals.selfbalance(ctx);
        jmp end;

        basefee:
        tempvar syscall_ptr = cast([fp - 7], felt*);
        tempvar pedersen_ptr = cast([fp - 6], HashBuiltin*);
        tempvar range_check_ptr = [fp];
        tempvar ctx = cast([fp - 3], model.ExecutionContext*);
        tempvar result = Uint256(0, 0);
        jmp end;

        end:
        // Rebind unused args with fp
        let opcode = cast([fp + 1], model.Opcode*);
        let bitwise_ptr = cast([fp - 4], BitwiseBuiltin*);

        // Rebind used args with ap
        let syscall_ptr = cast([ap - 6], felt*);
        let pedersen_ptr = cast([ap - 5], HashBuiltin*);
        let range_check_ptr = [ap - 4];
        let ctx = cast([ap - 3], model.ExecutionContext*);
        let result = Uint256([ap - 2], [ap - 1]);

        // Finalize opcode
        let stack = Stack.push_uint256(ctx.stack, result);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(ctx, opcode.gas);
        return ctx;
    }
}

namespace Internals {
    func blockhash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> (model.ExecutionContext*, Uint256) {
        if (ctx.stack.size == 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return (ctx, Uint256(0, 0));
        }

        let (stack, block_number_uint256) = Stack.pop(ctx.stack);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let block_number = block_number_uint256.low;

        // Check if blockNumber is within bounds by checking with current block number
        // Valid range is the last 256 blocks (not including the current one)
        let (current_block_number) = get_block_number();
        let in_range = is_in_range(block_number, current_block_number - 256, current_block_number);

        // If not in range, return 0
        if (in_range == FALSE) {
            return (ctx, Uint256(0, 0));
        }

        let (blockhash_registry_address_: felt) = blockhash_registry_address.read();
        let (blockhash_: felt) = IBlockhashRegistry.get_blockhash(
            contract_address=blockhash_registry_address_, block_number=[block_number_uint256]
        );
        let blockhash = Helpers.to_uint256(blockhash_);
        return (ctx, [blockhash]);
    }

    func selfbalance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> (model.ExecutionContext*, Uint256) {
        let (state, balance) = State.read_balance(ctx.state, ctx.call_context.address);
        let ctx = ExecutionContext.update_state(ctx, state);
        return (ctx, balance);
    }
}

// See model.Opcode
opcodes_label:
// BLOCKHASH
dw 20;  // gas
dw 1;  // stack_input
// COINBASE
dw 2;  // gas
dw 0;  // stack_input
// TIMESTAMP
dw 2;  // gas
dw 0;  // stack_input
// NUMBER
dw 2;  // gas
dw 0;  // stack_input
// PREVRANDAO
dw 2;  // gas
dw 0;  // stack_input
// GASLIMIT
dw 2;  // gas
dw 0;  // stack_input
// CHAINID
dw 2;  // gas
dw 0;  // stack_input
// SELFBALANCE
dw 5;  // gas
dw 0;  // stack_input
// BASEFEE
dw 2;  // gas
dw 0;  // stack_input
