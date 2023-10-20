// SPDX-License-Identifier: MIT
// Bare minimum contract for executing bytecode on the EVM interpreter

%lang starknet

// Starkware dependencies
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

// Local dependencies
from kakarot.evm import EVM
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.constants import (
    native_token_address,
    contract_account_class_hash,
    blockhash_registry_address,
    account_proxy_class_hash,
    Constants,
)

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt,
    contract_account_class_hash_: felt,
    account_proxy_class_hash_: felt,
    blockhash_registry_address_: felt,
) {
    native_token_address.write(native_token_address_);
    contract_account_class_hash.write(contract_account_class_hash_);
    account_proxy_class_hash.write(account_proxy_class_hash_);
    blockhash_registry_address.write(blockhash_registry_address_);
    return ();
}

func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    origin: felt,
    value: felt,
    bytecode_len: felt,
    bytecode: felt*,
    calldata_len: felt,
    calldata: felt*,
) -> EVM.Summary* {
    alloc_locals;
    tempvar address = new model.Address(1, 1);
    let summary = Kakarot.execute(
        address=address,
        is_deploy_tx=0,
        origin=origin,
        bytecode_len=bytecode_len,
        bytecode=bytecode,
        calldata_len=calldata_len,
        calldata=calldata,
        value=value,
        gas_limit=Constants.TRANSACTION_GAS_LIMIT,
        gas_price=0,
    );
    return summary;
}

@view
func evm_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    origin: felt,
    value: felt,
    bytecode_len: felt,
    bytecode: felt*,
    calldata_len: felt,
    calldata: felt*,
) -> (
    block_number: felt,
    block_timestamp: felt,
    stack_accesses_len: felt,
    stack_accesses: felt*,
    stack_len: felt,
    memory_accesses_len: felt,
    memory_accesses: felt*,
    memory_bytes_len: felt,
    accounts_accesses_len: felt,
    accounts_accesses: felt*,
    starknet_contract_address: felt,
    evm_contract_address: felt,
    return_data_len: felt,
    return_data: felt*,
    gas_used: felt,
    success: felt,
) {
    alloc_locals;
    let (local block_number) = get_block_number();
    let (local block_timestamp) = get_block_timestamp();
    let summary = execute(origin, value, bytecode_len, bytecode, calldata_len, calldata);

    let stack_accesses_len = summary.stack.squashed_end - summary.stack.squashed_start;
    let memory_accesses_len = summary.memory.squashed_end - summary.memory.squashed_start;
    let accounts_accesses_len = summary.state.accounts - summary.state.accounts_start;

    return (
        block_number=block_number,
        block_timestamp=block_timestamp,
        stack_accesses_len=stack_accesses_len,
        stack_accesses=summary.stack.squashed_start,
        stack_len=summary.stack.len_16bytes,
        memory_accesses_len=memory_accesses_len,
        memory_accesses=summary.memory.squashed_start,
        memory_bytes_len=summary.memory.bytes_len,
        accounts_accesses_len=accounts_accesses_len,
        accounts_accesses=summary.state.accounts_start,
        starknet_contract_address=summary.address.starknet,
        evm_contract_address=summary.address.evm,
        return_data_len=summary.return_data_len,
        return_data=summary.return_data,
        gas_used=summary.gas_used,
        success=1 - summary.reverted,
    );
}

@external
func evm_execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    origin: felt,
    value: felt,
    bytecode_len: felt,
    bytecode: felt*,
    calldata_len: felt,
    calldata: felt*,
) -> (return_data_len: felt, return_data: felt*, success: felt) {
    alloc_locals;
    let summary = execute(origin, value, bytecode_len, bytecode, calldata_len, calldata);
    let result = (summary.return_data_len, summary.return_data, 1 - summary.reverted);

    if (summary.reverted != FALSE) {
        return result;
    }

    State.commit(summary.state);
    return result;
}
