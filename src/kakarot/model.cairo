// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.uint256 import Uint256

namespace model {
    struct Stack {
        elements: Uint256*,
        raw_len: felt,
    }

    struct Memory {
        bytes: felt*,
        bytes_len: felt,  // The size is counted with the highest address that was accessed.
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
    }
}
