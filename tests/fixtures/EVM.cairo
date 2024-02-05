// SPDX-License-Identifier: MIT
// Bare minimum contract for executing bytecode on the EVM interpreter

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.library import Kakarot
from kakarot.interpreter import Interpreter
from kakarot.account import Account
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.constants import Constants
from kakarot.storages import (
    native_token_address,
    contract_account_class_hash,
    account_proxy_class_hash,
    precompiles_class_hash,
)
from backend.starknet import Starknet, Internals as StarknetInternals
from utils.dict import dict_keys, dict_values

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt,
    contract_account_class_hash_: felt,
    account_proxy_class_hash_: felt,
    precompiles_class_hash_: felt,
) {
    native_token_address.write(native_token_address_);
    contract_account_class_hash.write(contract_account_class_hash_);
    account_proxy_class_hash.write(account_proxy_class_hash_);
    precompiles_class_hash.write(precompiles_class_hash_);
    return ();
}

func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    env: model.Environment*,
    value: Uint256*,
    bytecode_len: felt,
    bytecode: felt*,
    calldata_len: felt,
    calldata: felt*,
    access_list_len: felt,
    access_list: felt*,
) -> (model.EVM*, model.Stack*, model.Memory*, model.State*, felt) {
    alloc_locals;
    let evm_address = 'target_evm_address';
    let starknet_address = Account.compute_starknet_address(evm_address);
    tempvar address = new model.Address(starknet_address, evm_address);
    let (evm, stack, memory, state, gas_used) = Interpreter.execute(
        env=env,
        address=address,
        is_deploy_tx=0,
        bytecode_len=bytecode_len,
        bytecode=bytecode,
        calldata_len=calldata_len,
        calldata=calldata,
        value=value,
        gas_limit=Constants.TRANSACTION_GAS_LIMIT,
        access_list_len=access_list_len,
        access_list=access_list,
    );
    return (evm, stack, memory, state, gas_used);
}

@view
func evm_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    origin: felt,
    value: Uint256,
    bytecode_len: felt,
    bytecode: felt*,
    calldata_len: felt,
    calldata: felt*,
    access_list_len: felt,
    access_list: felt*,
) -> (
    block_number: felt,
    block_timestamp: felt,
    stack_size: felt,
    stack_keys_len: felt,
    stack_keys: felt*,
    stack_values_len: felt,
    stack_values: Uint256*,
    memory_accesses_len: felt,
    memory_accesses: felt*,
    memory_words_len: felt,
    account_addresses_len: felt,
    account_addresses: felt*,
    starknet_contract_address: felt,
    evm_contract_address: felt,
    return_data_len: felt,
    return_data: felt*,
    gas_left: felt,
    success: felt,
    program_counter: felt,
) {
    alloc_locals;
    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;

    let env = Starknet.get_env(origin, 0);
    let (evm, stack, memory, state, _) = execute(
        env, &value, bytecode_len, bytecode, calldata_len, calldata, access_list_len, access_list
    );

    let (stack_keys_len, stack_keys) = dict_keys(stack.dict_ptr_start, stack.dict_ptr);
    let (stack_values_len, stack_values) = dict_values(stack.dict_ptr_start, stack.dict_ptr);

    let memory_accesses_len = memory.word_dict - memory.word_dict_start;

    // Return only accounts keys, ie. touched starknet addresses
    let (account_addresses_len, account_addresses) = dict_keys(
        state.accounts_start, state.accounts
    );
    let is_reverted = is_not_zero(evm.reverted);

    return (
        block_number=env.block_number,
        block_timestamp=env.block_timestamp,
        stack_size=stack.size,
        stack_keys_len=stack_keys_len,
        stack_keys=stack_keys,
        stack_values_len=stack_values_len,
        stack_values=stack_values,
        memory_accesses_len=memory_accesses_len,
        memory_accesses=memory.word_dict_start,
        memory_words_len=memory.words_len,
        account_addresses_len=account_addresses_len,
        account_addresses=account_addresses,
        starknet_contract_address=evm.message.address.starknet,
        evm_contract_address=evm.message.address.evm,
        return_data_len=evm.return_data_len,
        return_data=evm.return_data,
        gas_left=evm.gas_left,
        success=1 - is_reverted,
        program_counter=evm.program_counter,
    );
}

@external
func evm_execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    origin: felt,
    value: Uint256,
    bytecode_len: felt,
    bytecode: felt*,
    calldata_len: felt,
    calldata: felt*,
    access_list_len: felt,
    access_list: felt*,
) -> (return_data_len: felt, return_data: felt*, success: felt) {
    alloc_locals;
    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;

    let env = Starknet.get_env(origin, 0);
    let (evm, stack, memory, state, _) = execute(
        env, &value, bytecode_len, bytecode, calldata_len, calldata, access_list_len, access_list
    );
    let is_reverted = is_not_zero(evm.reverted);
    let result = (evm.return_data_len, evm.return_data, 1 - is_reverted);

    if (evm.reverted != FALSE) {
        return result;
    }

    // We just emit the events as committing the accounts is out of the scope of these EVM
    // tests and requires a real Message.address (not Address(1, 1))
    StarknetInternals._emit_events(state.events_len, state.events);
    return result;
}

// @notice Compute the starknet address of a contract given its EVM address
// @param evm_address The EVM address of the contract
// @return contract_address The starknet address of the contract
@view
func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    let starknet_address = Account.compute_starknet_address(evm_address);
    return (contract_address=starknet_address);
}
