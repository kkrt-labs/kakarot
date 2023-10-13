// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import DictAccess
from starkware.cairo.common.math import assert_le, assert_nn
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import emit_event

// Internal dependencies
from kakarot.accounts.library import Accounts
from kakarot.constants import Constants
from kakarot.errors import Errors
from kakarot.interfaces.interfaces import IAccount, IContractAccount
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.utils import Helpers

// @title ExecutionContext related functions.
// @notice This file contains functions related to the execution context.
namespace ExecutionContext {
    // Summary of the execution. Created upon finalization of the execution.
    struct Summary {
        memory: Memory.Summary*,
        stack: Stack.Summary*,
        return_data: felt*,
        return_data_len: felt,
        gas_used: felt,
        starknet_contract_address: felt,
        evm_contract_address: felt,
        reverted: felt,
        selfdestruct_contracts_len: felt,
        selfdestruct_contracts: felt*,
        calling_context: model.ExecutionContext*,
    }

    // @notice Initialize an empty context to act as a placeholder for root context.
    // @return ExecutionContext A stopped execution context.
    func init_empty() -> model.ExecutionContext* {
        let (root_context) = get_label_location(empty_context);
        let self = cast(root_context, model.ExecutionContext*);
        return self;

        empty_context:
        dw 0;  // call_context
        dw 0;  // program_counter
        dw 1;  // stopped
        dw 0;  // return_data
        dw 0;  // return_data_len
        dw 0;  // stack
        dw 0;  // memory
        dw 0;  // gas_used
        dw 0;  // gas_limit
        dw 0;  // gas_price
        dw 0;  // starknet_contract_address
        dw 0;  // evm_contract_address
        dw 0;  // origin
        dw 0;  // calling_context
        dw 0;  // selfdestruct_contracts_len
        dw 0;  // selfdestruct_contracts
        dw 0;  // events_len
        dw 0;  // events
        dw 0;  // create_contracts_len
        dw 0;  // create_contracts
        dw 0;  // revert_contract_state
        dw 0;  // reverted
        dw 0;  // read only
    }

    // @notice Initialize the execution context.
    // @dev Initialize the execution context of a specific contract.
    // @param call_context The call_context (see model.CallContext) to be executed.
    // @param starknet_contract_address The context starknet address.
    // @param evm_contract_address The context corresponding evm address.
    // @param origin The caller EVM address
    // @param gas_limit The available gas for the ExecutionContext.
    // @param gas_price The price per unit of gas.
    // @param calling_context A reference to the context of the calling contract. This context stores the return data produced by the called contract in its memory.
    // @param return_data_len The return_data length.
    // @param return_data The region where returned data of the contract or precompile is written.
    // @param read_only The boolean that determines whether state modifications can be executed from the sub-execution context.
    // @return ExecutionContext The initialized execution context.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        call_context: model.CallContext*,
        starknet_contract_address: felt,
        evm_contract_address: felt,
        origin: felt,
        gas_limit: felt,
        gas_price: felt,
        calling_context: model.ExecutionContext*,
        return_data_len: felt,
        return_data: felt*,
        read_only: felt,
    ) -> model.ExecutionContext* {
        alloc_locals;
        let (empty_selfdestruct_contracts: felt*) = alloc();
        let (empty_events: model.Event*) = alloc();
        let (empty_create_contracts: felt*) = alloc();
        let (local revert_contract_state_dict_start) = default_dict_new(0);
        tempvar revert_contract_state: model.RevertContractState* = new model.RevertContractState(
            revert_contract_state_dict_start, revert_contract_state_dict_start
        );

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();

        return new model.ExecutionContext(
            call_context=call_context,
            program_counter=0,
            stopped=FALSE,
            return_data=return_data,
            return_data_len=return_data_len,
            stack=stack,
            memory=memory,
            gas_used=0,
            gas_limit=gas_limit,
            gas_price=gas_price,
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=evm_contract_address,
            origin=origin,
            calling_context=calling_context,
            selfdestruct_contracts_len=0,
            selfdestruct_contracts=empty_selfdestruct_contracts,
            events_len=0,
            events=empty_events,
            create_addresses_len=0,
            create_addresses=empty_create_contracts,
            revert_contract_state=revert_contract_state,
            reverted=FALSE,
            read_only=read_only,
        );
    }

    // @notice Compute the intrinsic gas cost of the current transaction.
    // @dev Computes with the intrinsic gas cost based on per transaction constant and cost of input data (16 gas per non-zero byte and 4 gas per zero byte).
    // @param self The execution context.
    // @return intrinsic gas cost.
    func compute_intrinsic_gas_cost(self: model.ExecutionContext*) -> felt {
        let calldata = self.call_context.calldata;
        let calldata_len = self.call_context.calldata_len;
        let count = Helpers.count_nonzeroes(nonzeroes=0, idx=0, arr_len=calldata_len, arr=calldata);
        let zeroes = calldata_len - count.nonzeroes;
        let calldata_cost = zeroes * 4 + count.nonzeroes * 16;

        return (Constants.TRANSACTION_INTRINSIC_GAS_COST + calldata_cost);
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
    // @return ExecutionContext The pointer to the updated execution context.
    func stop(self: model.ExecutionContext*) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=TRUE,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Return whether the current execution context is reverted.
    // @dev When the execution context is reverted, no more instructions can be executed (it is stopped) and its contract creation and contract storage writes are reverted on its finalization.
    // @param self The pointer to the execution context.
    // @return is_reverted TRUE if the execution context is reverted, FALSE otherwise.
    func is_reverted(self: model.ExecutionContext*) -> felt {
        return self.reverted;
    }

    // @notice Revert the current execution context.
    // @dev When the execution context is reverted, no more instructions can be executed (it is stopped) and its contract creation and contract storage writes are reverted on its finalization.
    // @param self The pointer to the execution context.
    // @param revert_reason The byte array of the revert reason.
    // @param size The size of the byte array.
    // @return ExecutionContext The pointer to the updated execution context.
    func revert(
        self: model.ExecutionContext*, revert_reason: felt*, size: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=TRUE,
            return_data=revert_reason,
            return_data_len=size,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=TRUE,
            read_only=self.read_only,
        );
    }

    // @notice Finalizes the execution context.
    // @dev See https://www.cairo-lang.org/docs/reference/common_library.html#dictaccess
    //      TL;DR: ensure that the prover used values that are consistent with the dictionary.
    // @param self The pointer to the execution context.
    // @return Summary The pointer to the execution Summary.
    func finalize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.ExecutionContext*) -> Summary* {
        alloc_locals;
        let memory_summary = Memory.finalize(self.memory);
        let stack_summary = Stack.finalize(self.stack);
        Internals._finalize_state_updates(self);

        return new Summary(
            memory=memory_summary,
            stack=stack_summary,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            gas_used=self.gas_used,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            reverted=self.reverted,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            calling_context=self.calling_context,
        );
    }

    // @notice Read and return data from bytecode.
    // @dev The data is read from the bytecode from the current program counter.
    // @param self The pointer to the execution context.
    // @param len The size of the data to read.
    // @return self The pointer to the updated execution context.
    // @return output The data read from the bytecode.
    func read_code(self: model.ExecutionContext*, len: felt) -> (
        self: model.ExecutionContext*, output: felt*
    ) {
        alloc_locals;
        // Get current pc value
        let pc = self.program_counter;
        let (output: felt*) = alloc();
        // Copy code slice
        memcpy(dst=output, src=self.call_context.bytecode + pc, len=len);
        // Move program counter
        let self = ExecutionContext.increment_program_counter(self=self, inc_value=len);
        return (self=self, output=output);
    }

    // @notice Update the stack of the current execution context.
    // @dev The stack is updated with the given stack.
    // @param self The pointer to the execution context.
    // @param stack The pointer to the new stack.
    // @return ExecutionContext The pointer to the updated execution context.
    func update_stack(
        self: model.ExecutionContext*, new_stack: model.Stack*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=new_stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Update the memory of the current execution context.
    // @dev The memory is updated with the given memory.
    // @param self The pointer to the execution context.
    // @param memory The pointer to the new memory.
    // @return ExecutionContext The pointer to the updated execution context.
    func update_memory(
        self: model.ExecutionContext*, new_memory: model.Memory*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=new_memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Update the return data of the current execution context.
    // @dev The memory is updated with the given memory.
    // @param self The pointer to the execution context.
    // @param return_data_len The length of the return data array.
    // @param return_data The return data array.
    // @return ExecutionContext The pointer to the updated execution context.
    func update_return_data{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        self: model.ExecutionContext*, return_data_len: felt, return_data: felt*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=return_data,
            return_data_len=return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
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
            call_context=self.call_context,
            program_counter=self.program_counter + inc_value,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Increment the gas used.
    // @dev The gas used is incremented by the given value.
    // @param self The pointer to the execution context.
    // @param inc_value The value to increment the gas used with.
    // @return ExecutionContext The pointer to the updated execution context.
    func increment_gas_used(
        self: model.ExecutionContext*, inc_value: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used + inc_value,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Update the starknet and evm contract addresses.
    // @dev No check is made using the registry for these two addresses being actually linked.
    // @param self The pointer to the execution context.
    // @param starknet_contract_address The starknet_contract_address to use.
    // @param evm_contract_address The evm_contract_address to use.
    // @return ExecutionContext The pointer to the updated execution context.
    func update_addresses(
        self: model.ExecutionContext*, starknet_contract_address: felt, evm_contract_address: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Update the array of contracts to destroy.
    // @param self The pointer to the execution context.
    // @param selfdestruct_contracts_len Array length of selfdestruct_contracts to add.
    // @param selfdestruct_contracts The pointer to the new array of contracts to destroy.
    // @return ExecutionContext The pointer to the updated execution context.
    func push_to_selfdestruct_contracts(
        self: model.ExecutionContext*,
        selfdestruct_contracts_len: felt,
        selfdestruct_contracts: felt*,
    ) -> model.ExecutionContext* {
        Helpers.fill_array(
            fill_len=selfdestruct_contracts_len,
            input_arr=selfdestruct_contracts,
            output_arr=self.selfdestruct_contracts + self.selfdestruct_contracts_len,
        );
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len + selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Update the array of events to emit in the case of a execution context successfully running to completion (see `LoggingHelper.finalize`).
    // @param self The pointer to the execution context.
    // @param selfdestruct_contracts_len Array length of events to add.
    // @param selfdestruct_contracts The pointer to the new array of contracts to destroy.
    func push_event_to_emit(
        self: model.ExecutionContext*,
        event_keys_len: felt,
        event_keys: Uint256*,
        event_data_len: felt,
        event_data: felt*,
    ) -> model.ExecutionContext* {
        let event: model.Event = model.Event(
            keys_len=event_keys_len, keys=event_keys, data_len=event_data_len, data=event_data
        );
        assert [self.events + self.events_len * model.Event.SIZE] = event;
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len + 1,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Add one contract to the array of create contracts to destroy in the case of the execution context reverting.
    // @param self The pointer to the execution context.
    // @param create_contract_address The address of the contract from the create(2) opcode called from the execution context.
    func push_create_address(
        self: model.ExecutionContext*, create_contract_address: felt
    ) -> model.ExecutionContext* {
        assert [self.create_addresses + self.create_addresses_len] = create_contract_address;
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len + 1,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Add one contract to the array of contracts to destroy.
    // @param self The pointer to the execution context.
    // @param destroy_contract contract to destroy.
    // @return ExecutionContext The pointer to the updated execution context.
    func push_to_destroy_contract(
        self: model.ExecutionContext*, destroy_contract: felt
    ) -> model.ExecutionContext* {
        assert [self.selfdestruct_contracts + self.selfdestruct_contracts_len] = destroy_contract;
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=TRUE,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len + 1,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }

    // @notice Updates the dictionary that keeps track of the prior-to-first-write value of a contract storage key so it can be reverted to if the writing execution context reverts.
    // @param self The pointer to the execution context.
    // @param dict_end   The pointer to the updated end of the DictAccess array.
    func update_revert_contract_state(
        self: model.ExecutionContext*, dict_end: DictAccess*
    ) -> model.ExecutionContext* {
        tempvar revert_contract_state: model.RevertContractState* = new model.RevertContractState(
            self.revert_contract_state.dict_start, dict_end
        );
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=FALSE,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
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
            let ctx = ExecutionContext.revert(self, revert_reason, revert_reason_len);
            return ctx;
        }

        if ([self.call_context.bytecode + new_pc_offset] != 0x5b) {
            let (revert_reason_len, revert_reason) = Errors.jumpToNonJumpdest();
            let ctx = ExecutionContext.revert(self, revert_reason, revert_reason_len);
            return ctx;
        }

        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=new_pc_offset,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            origin=self.origin,
            calling_context=self.calling_context,
            selfdestruct_contracts_len=self.selfdestruct_contracts_len,
            selfdestruct_contracts=self.selfdestruct_contracts,
            events_len=self.events_len,
            events=self.events,
            create_addresses_len=self.create_addresses_len,
            create_addresses=self.create_addresses,
            revert_contract_state=self.revert_contract_state,
            reverted=self.reverted,
            read_only=self.read_only,
        );
    }
}

namespace Internals {
    // @notice Iterates through a list of events and emits them on the case that a context ran successfully (stopped and not reverted).
    // @param evm_contract_address The execution context's evm contract address.
    // @param events_len The length of the events array.
    // @param events The array of Event structs that are emitted via the `emit_event` syscall.
    func _emit_events{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_contract_address: felt, events_len: felt, events: model.Event*) {
        alloc_locals;

        if (events_len == 0) {
            return ();
        }

        let event: model.Event = [events];
        let event_keys_felt = cast(event.keys, felt*);
        // we add the operating evm_contract_address of an execution context
        // as the first key of an event
        // we track kakarot events as those emitted from the kkrt contract
        // and map it to the kkrt contract via this convention
        let (event_keys: felt*) = alloc();
        memcpy(dst=event_keys + 1, src=event_keys_felt, len=event.keys_len);
        assert [event_keys] = evm_contract_address;
        let updated_event_len = event.keys_len + 1;

        emit_event(
            keys_len=updated_event_len, keys=event_keys, data_len=event.data_len, data=event.data
        );
        // we maintain the semantics of one event struct involves iterating a full event struct size recursively
        _emit_events(evm_contract_address, events_len - 1, events + 1 * model.Event.SIZE);
        return ();
    }

    // @notice Finalize the state updates brought by this ExecutionContext: contract creation, balances, sstore and events.
    // @param self The ExecutionContext.
    func _finalize_state_updates{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.ExecutionContext*) {
        alloc_locals;
        let (dict_start, dict_end) = default_dict_finalize(
            self.revert_contract_state.dict_start, self.revert_contract_state.dict_end, 0
        );

        if (self.reverted == 0) {
            _emit_events(self.evm_contract_address, self.events_len, self.events);
            return ();
        }

        _finalize_storage_updates(
            starknet_contract_address=self.starknet_contract_address,
            dict_start=dict_start,
            dict_end=dict_end,
        );
        Helpers.erase_contracts(self.create_addresses_len, self.create_addresses);
        return ();
    }

    // @notice Iterates through the `revert_contract_state` dict and restores a contract state to what it was prior to the reverting execution context's writes.
    // @param starknet_contract_address The contract address whose state is being restored to prior the execution contexts writes.
    // @param reverted Whether the ExecutionContext was reverted or not
    // @param dict_start The start of the `revert_contract_state` dict.
    // @param dict_end The end of the `revert_contract_state` dict.
    // @return ExecutionContext The pointer to the updated execution context.
    func _finalize_storage_updates{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(starknet_contract_address: felt, dict_start: DictAccess*, dict_end: DictAccess*) {
        alloc_locals;
        if (dict_start == dict_end) {
            return ();
        }

        let reverted_state = dict_start.new_value;
        let casted_reverted_state = cast(reverted_state, model.KeyValue*);
        IContractAccount.write_storage(
            contract_address=starknet_contract_address,
            key=casted_reverted_state.key,
            value=casted_reverted_state.value,
        );
        return _finalize_storage_updates(
            starknet_contract_address=starknet_contract_address,
            dict_start=dict_start + DictAccess.SIZE,
            dict_end=dict_end,
        );
    }
}
