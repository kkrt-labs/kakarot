// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import DictAccess, dict_write, dict_read
from starkware.cairo.common.math import assert_le, assert_nn
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from kakarot.account import Account
from kakarot.constants import Constants
from kakarot.errors import Errors
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from utils.utils import Helpers
from utils.bytes import felt_to_ascii
// @title ExecutionContext related functions.
// @notice This file contains functions related to the execution context.
namespace ExecutionContext {
    // Summary of the execution. Created upon finalization of the execution.
    struct Summary {
        memory: Memory.Summary*,
        stack: Stack.Summary*,
        return_data_len: felt,
        return_data: felt*,
        gas_used: felt,
        address: model.Address*,
        reverted: felt,
        state: model.State*,
        calling_context: model.ExecutionContext*,
        call_context: model.CallContext*,
        program_counter: felt,
    }

    // @notice Initialize an empty context to act as a placeholder for root context.
    // @return ExecutionContext A stopped execution context.
    func init_empty() -> model.ExecutionContext* {
        let (root_context) = get_label_location(empty_context);
        let self = cast(root_context, model.ExecutionContext*);
        return self;

        empty_context:
        dw 0;  // state
        dw 0;  // call_context
        dw 0;  // stack
        dw 0;  // memory
        dw 0;  // return_data_len
        dw 0;  // return_data
        dw 0;  // program_counter
        dw 1;  // stopped
        dw 0;  // gas_used
        dw 0;  // reverted
    }

    // @notice Initialize the execution context.
    // @dev Initialize the execution context of a specific contract.
    // @param call_context The call_context (see model.CallContext) to be executed.
    // @return ExecutionContext The initialized execution context.
    func init(call_context: model.CallContext*, gas_used: felt) -> model.ExecutionContext* {
        let stack = Stack.init();
        let memory = Memory.init();
        let state = State.init();
        let (return_data: felt*) = alloc();

        return new model.ExecutionContext(
            state=state,
            call_context=call_context,
            stack=stack,
            memory=memory,
            return_data_len=0,
            return_data=return_data,
            program_counter=0,
            stopped=FALSE,
            gas_used=gas_used,
            reverted=FALSE,
        );
    }

    // @notice Return whether the current execution context is stopped.
    // @dev When the execution context is stopped, no more instructions can be executed.
    // @param self The pointer to the execution context.
    // @return is_stopped TRUE if the execution context is stopped, FALSE otherwise.
    func is_stopped(self: model.ExecutionContext*) -> felt {
        return self.stopped;
    }

    // @notice Return whether the current execution context is empty (dummy) or a real context.
    // @dev When the calling_context of an execution context is empty, no calling context can be called when this context stops.
    // @param self The pointer to the execution context.
    // @return  TRUE if the execution context is empty, FALSE otherwise.
    func is_empty(self: model.ExecutionContext*) -> felt {
        if (cast(self.call_context, felt) == 0) {
            return TRUE;
        }
        return FALSE;
    }

    // @notice Stop the current execution context.
    // @dev When the execution context is stopped, no more instructions can be executed.
    // @param self The pointer to the execution context.
    // @param return_data_len The length of the return_data.
    // @param return_data The pointer to the return_data array.
    // @param reverted A boolean indicating whether the ExecutionContext is reverted or not.
    // @return ExecutionContext The pointer to the updated execution context.
    func stop(
        self: model.ExecutionContext*, return_data_len: felt, return_data: felt*, reverted: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            state=self.state,
            call_context=self.call_context,
            stack=self.stack,
            memory=self.memory,
            return_data_len=return_data_len,
            return_data=return_data,
            program_counter=self.program_counter,
            stopped=TRUE,
            gas_used=self.gas_used,
            reverted=reverted,
        );
    }

    // @notice Return whether the current execution context is reverted.
    // @dev When the execution context is reverted, no more instructions can be executed (it is stopped) and its contract creation and contract storage writes are reverted on its finalization.
    // @param self The pointer to the execution context.
    // @return is_reverted TRUE if the execution context is reverted, FALSE otherwise.
    func is_reverted(self: model.ExecutionContext*) -> felt {
        return self.reverted;
    }

    // @notice Finalizes the execution context.
    // @dev See https://www.cairo-lang.org/docs/reference/common_library.html#dictaccess
    //      TL;DR: ensure that the prover used values that are consistent with the dictionary.
    // @param self The pointer to the execution context.
    // @return Summary The pointer to the execution Summary.
    func finalize{range_check_ptr}(self: model.ExecutionContext*) -> Summary* {
        alloc_locals;
        let memory_summary = Memory.finalize(self.memory);
        let stack_summary = Stack.finalize(self.stack);
        State.finalize(self.state);

        return new Summary(
            memory=memory_summary,
            stack=stack_summary,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            gas_used=self.gas_used,
            address=self.call_context.address,
            reverted=self.reverted,
            state=self.state,
            calling_context=self.call_context.calling_context,
            call_context=self.call_context,
            program_counter=self.program_counter,
        );
    }

    // @notice Update the stack of the current execution context.
    // @dev The stack is updated with the given stack.
    // @param self The pointer to the execution context.
    // @param stack The pointer to the new stack.
    // @return ExecutionContext The pointer to the updated execution context.
    func update_stack(
        self: model.ExecutionContext*, stack: model.Stack*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            state=self.state,
            call_context=self.call_context,
            stack=stack,
            memory=self.memory,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=self.program_counter,
            stopped=self.stopped,
            gas_used=self.gas_used,
            reverted=self.reverted,
        );
    }

    // @notice Update the memory of the current execution context.
    // @dev The memory is updated with the given memory.
    // @param self The pointer to the execution context.
    // @param memory The pointer to the new memory.
    // @return ExecutionContext The pointer to the updated execution context.
    func update_memory(
        self: model.ExecutionContext*, memory: model.Memory*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            state=self.state,
            call_context=self.call_context,
            stack=self.stack,
            memory=memory,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=self.program_counter,
            stopped=self.stopped,
            gas_used=self.gas_used,
            reverted=self.reverted,
        );
    }

    // @notice Increment the program counter.
    // @dev The program counter is incremented by the given value.
    // @param self The pointer to the execution context.
    // @param inc_value The value to increment the program counter with.
    // @return ExecutionContext The pointer to the updated execution context.
    func increment_program_counter(
        self: model.ExecutionContext*, inc_value: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            state=self.state,
            call_context=self.call_context,
            stack=self.stack,
            memory=self.memory,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=self.program_counter + inc_value,
            stopped=self.stopped,
            gas_used=self.gas_used,
            reverted=self.reverted,
        );
    }

    // @notice Increment the gas used.
    // @dev The gas used is incremented by the given value.
    // @param self The pointer to the execution context.
    // @param inc_value The value to increment the gas used with.
    // @return ExecutionContext The pointer to the updated execution context.
    func charge_gas{range_check_ptr}(
        self: model.ExecutionContext*, inc_value: felt
    ) -> model.ExecutionContext* {
        let gas_used = self.gas_used + inc_value;
        let out_of_gas = is_le(self.call_context.gas_limit, gas_used - 1);

        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas(
                self.call_context.gas_limit, gas_used
            );
            return new model.ExecutionContext(
                state=self.state,
                call_context=self.call_context,
                stack=self.stack,
                memory=self.memory,
                return_data_len=revert_reason_len,
                return_data=revert_reason,
                program_counter=self.program_counter,
                stopped=TRUE,
                gas_used=self.call_context.gas_limit,
                reverted=TRUE,
            );
        }

        return new model.ExecutionContext(
            state=self.state,
            call_context=self.call_context,
            stack=self.stack,
            memory=self.memory,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=self.program_counter,
            stopped=self.stopped,
            gas_used=gas_used,
            reverted=self.reverted,
        );
    }

    // @notice Update the array of events to emit in the case of a execution context successfully running to completion (see `ExecutionContext.finalize`).
    // @param self The pointer to the execution context.
    // @param topics_len The length of the topics
    // @param topics The topics Uint256 array
    // @param data_len The length of the data
    // @param data The data bytes array
    func push_event(
        self: model.ExecutionContext*,
        topics_len: felt,
        topics: Uint256*,
        data_len: felt,
        data: felt*,
    ) -> model.ExecutionContext* {
        alloc_locals;

        // we add the operating evm_contract_address of the execution context
        // as the first key of an event
        // we track kakarot events as those emitted from the kkrt contract
        // and map it to the corresponding EVM contract via this convention
        // this looks a bit odd and may need to be reviewed
        let (local topics_with_address: felt*) = alloc();
        assert [topics_with_address] = self.call_context.address.evm;
        memcpy(dst=topics_with_address + 1, src=cast(topics, felt*), len=topics_len * Uint256.SIZE);
        let event = model.Event(
            topics_len=1 + topics_len * Uint256.SIZE,
            topics=topics_with_address,
            data_len=data_len,
            data=data,
        );

        let state = State.add_event(self.state, event);

        return ExecutionContext.update_state(self, state);
    }

    // @notice Updates the dictionary that keeps track of the prior-to-first-write value of a contract storage key so it can be reverted to if the writing execution context reverts.
    // @param self The pointer to the execution context.
    // @param state The pointer to model.State
    func update_state(
        self: model.ExecutionContext*, state: model.State*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            state=state,
            call_context=self.call_context,
            stack=self.stack,
            memory=self.memory,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=self.program_counter,
            stopped=self.stopped,
            gas_used=self.gas_used,
            reverted=self.reverted,
        );
    }

    // @notice Update the program counter.
    // @dev The program counter is updated to a given value. This is only ever called by JUMP or JUMPI
    // @param self The pointer to the execution context.
    // @param new_pc_offset The value to update the program counter by.
    // @return ExecutionContext The pointer to the updated execution context.
    func jump{range_check_ptr}(
        self: model.ExecutionContext*, new_pc_offset: felt
    ) -> model.ExecutionContext* {
        alloc_locals;

        let is_nn_pc = is_nn(new_pc_offset);
        let is_le_bytecode_len = is_le(new_pc_offset, self.call_context.bytecode_len - 1);
        if (is_nn_pc + is_le_bytecode_len != 2) {
            let (revert_reason_len, revert_reason) = Errors.programCounterOutOfRange();
            let ctx = ExecutionContext.stop(self, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        if ([self.call_context.bytecode + new_pc_offset] != 0x5b) {
            let (revert_reason_len, revert_reason) = Errors.jumpToNonJumpdest();
            let ctx = ExecutionContext.stop(self, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        return new model.ExecutionContext(
            state=self.state,
            call_context=self.call_context,
            stack=self.stack,
            memory=self.memory,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=new_pc_offset,
            stopped=self.stopped,
            gas_used=self.gas_used,
            reverted=self.reverted,
        );
    }
}
