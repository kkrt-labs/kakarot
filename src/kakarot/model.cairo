// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict import DictAccess

namespace model {
    // @notice Info: https://www.evm.codes/about#stack
    // @notice Stack with a 1024 items maximum size. Each item is a 256 bits word. The stack is used by most
    // @notice opcodes to consume their parameters from.
    // @dev Each word is represented by two 128bits (16bytes) chunks.
    // @param word_dict_start pointer to a DictAccess array used to store the stack's value at a given index.
    // @param word_dict pointer to the end of the DictAccess array.
    // @param len_16_bytes length of the DictAccess array.
    struct Stack {
        word_dict_start: DictAccess*,
        word_dict: DictAccess*,
        len_16bytes: felt,
    }

    // @notice info: https://www.evm.codes/about#memory
    // @notice Transient memory maintained by the EVM during an execution which doesn't persist
    // @notice between transactions.
    // @param word_dict_start pointer to a DictAccess used to store the memory's value at a given index.
    // @param word_dict pointer to the end of the DictAccess array.
    // @param bytes_len length of the DictAccess array.
    struct Memory {
        word_dict_start: DictAccess*,
        word_dict: DictAccess*,
        bytes_len: felt,
    }

    // @notice info: https://www.evm.codes/about#calldata
    // @notice Struct storing data related to a call.
    // @param bytecode The executed bytecode.
    // @param bytecode_len The length of bytecode.
    // @param calldata byte The space where the data parameter of a transaction or call is held.
    // @param calldata_len The length of calldata.
    // @param value The amount of native token to transfer.
    struct CallContext {
        bytecode: felt*,
        bytecode_len: felt,
        calldata: felt*,
        calldata_len: felt,
        value: felt,
    }

    // @notice A dictionary that keeps track of the prior-to-first-write-of-operating-execution-context value of a contract storage key so it can be reverted to if the writing execution context reverts.
    // @param dict_start pointer to a DictAccess used to store the revert contract states's value at a contract storage key.
    // @param dict_start The pointer to the end of the DictAccess array.
    // @param dict_end The pointer to the end of the DictAccess array.
    struct RevertContractState {
        dict_start: DictAccess*,
        dict_end: DictAccess*,
    }

    // @notice The prior-to-first-write-of-operating-execution-context value of a contract storage key in `RevertContractState`
    // @param key The key of memory of contract storage (see `MemoryOperations.exec_sstore`).
    // @param value The value of memory of contract storage (see `MemoryOperations.exec_sstore`).
    struct KeyValue {
        key: Uint256,
        value: Uint256,
    }

    // TODO: possible to just import `EmitEvent` struct from `starkware.starknet.common.syscalls`
    // @notice info: https://www.evm.codes/about#calldata
    // @notice Struct storing data related to an event emitting, as in when calling `emit_event`
    // @notice conveying the data as a struct is necessary because we want to delay the actual emitting until an execution context is completed and not reverted
    struct Event {
        keys_len: felt,
        keys: Uint256*,
        data_len: felt,
        data: felt*,
    }

    // @dev Stores all data relevant to the current execution context.
    // @param call_context The call context data.
    // @param program_counter The keep track of the current position in the program as it is being executed.
    // @param stopped A boolean that state if the current execution is halted.
    // @param return_data The region used to return a value after a call.
    // @param return_data_len The return_data length.
    // @param stack The current execution context stack.
    // @param memory The current execution context memory.
    // @param gas_used The gas consumed by the current state of the execution.
    // @param gas_limit The maximum amount of gas for the execution.
    // @param gas_price The amount to pay per unit of gas.
    // @param starknet_contract_address The starknet address of the contract interacted with.
    // @param evm_contract_address The evm address of the contract interacted with.
    // @param calling_context The parent context of the current execution context, can be empty when context
    //                        is root context | see ExecutionContext.is_root(ctx).
    // @param destroy_contracts_len The destroy_contract length.
    // @param destroy_contracts The array of contracts to destroy at the end of the transaction.
    // @param events_len The events length.
    // @param events The events to be emitted upon a non-reverted stopped execution context.
    // @param create_addresses_len The create_addresses length.
    // @param create_addresses The addresses of contracts initialized by the create(2) opcodes that are deleted if the creating context is reverted.
    // @param revert_contract_state A dictionary that keeps track of the prior-to-first-write value of a contract storage key so it can be reverted to if the writing execution context reverts.
    // @param read_only if set to true, context cannot do any state modifying instructions or send ETH in the sub context.
    struct ExecutionContext {
        call_context: CallContext*,
        program_counter: felt,
        stopped: felt,
        return_data: felt*,
        return_data_len: felt,
        stack: Stack*,
        memory: Memory*,
        gas_used: felt,
        gas_limit: felt,
        gas_price: felt,
        starknet_contract_address: felt,
        evm_contract_address: felt,
        origin: felt,
        calling_context: ExecutionContext*,
        destroy_contracts_len: felt,
        destroy_contracts: felt*,
        events_len: felt,
        events: Event*,
        create_addresses_len: felt,
        create_addresses: felt*,
        revert_contract_state: RevertContractState*,
        reverted: felt,
        read_only: felt,
    }
}
