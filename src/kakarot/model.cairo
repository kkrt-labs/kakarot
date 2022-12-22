// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict import DictAccess

namespace model {

    // @notice info: https://www.evm.codes/about#stack
    // @notice Stack with a 1024 items maximum size. Each item is a 256 bits word. The stack is used by most 
    // @notice opcodes to consume their parameters from.
    // @dev Each word is represented by two 128bits (16bytes) chunks.
    // @param word_dict_start - pointer to a DictAccess array used to store the stack's value at a given index
    // @param word_dict - pointer to the end of the DictAccess array
    // @param len_16_bytes - length of the DictAccess array
    struct Stack {
        word_dict_start: DictAccess*,
        word_dict: DictAccess*,
        len_16bytes: felt,
    }

    // @notice info: https://www.evm.codes/about#memory
    // @notice Transient memory maintained by the EVM during an execution which doesn't persist
    // @notice between transactions.
    // @param word_dict_start - pointer to a DictAccess used to store the memory's value at a given index
    // @param word_dict - pointer to the end of the DictAccess array
    // @param len_16_bytes - length of the DictAccess array
    struct Memory {
        word_dict_start: DictAccess*,
        word_dict: DictAccess*,
        bytes_len: felt,
    }

    // @notice info: https://www.evm.codes/about#calldata
    // @notice Struct storing data related to a call
    // @param bytecode - smart contract bytecode
    // @param bytecode_len - length of bytecode
    // @param calldata - byte space where the data parameter of a transaction or call is held
    // @param calldata_len - length of calldata
    // @param value - amount of native token to transfer
    struct CallContext {
        bytecode: felt*,
        bytecode_len: felt,
        calldata: felt*,
        calldata_len: felt,
        value: felt,
    }

    // @dev Stores all data relevant to the current execution context
    // @param call_context - call context data
    // @param program_counter - keep track of the current position in the program as it is being executed
    // @param stopped - boolean that state if the current execution is halted
    // @param return_data - region used to return a value after a call
    // @param return_data_len - return_data length
    // @param stack - current execution context stack
    // @param memory - current execution context memory
    // @param gas_used - gas consumed by the current state of the execution
    // @param gas_limit - maximum amount of gas for the execution
    // @param gas_price - the amount to pay per unit of gas
    // @param starknet_contract_address - starknet address of the contract interacted with
    // @param evm_contract_address - evm address of the contract interacted with
    // @param calling_context - parent context of the current execution context (optional)
    // @param sub_context - child context of the current execution context (optional)
    // @param destroy_contracts_len - destroy_contract length
    // @param destroy_contracts - array of contracts to destroy at the end of the transaction
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
        calling_context: ExecutionContext*,
        sub_context: ExecutionContext*,
        destroy_contracts_len: felt,
        destroy_contracts: felt*,
    }
}
