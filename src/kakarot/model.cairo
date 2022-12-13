// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict import DictAccess

namespace model {
    struct Stack {
        word_dict_start: DictAccess*,
        word_dict: DictAccess*,
        len_16bytes: felt,
    }

    struct Memory {
        word_dict_start: DictAccess*,
        word_dict: DictAccess*,
        bytes_len: felt,
    }

    struct CallContext {
        bytecode: felt*,
        bytecode_len: felt,
        calldata: felt*,
        calldata_len: felt,
        value: felt,
    }

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
        intrinsic_gas_cost: felt,
        starknet_contract_address: felt,
        evm_contract_address: felt,
        calling_context: ExecutionContext*,
        sub_context: ExecutionContext*,
        destroy_contracts_len: felt,
        destroy_contracts: felt*,
    }
}
