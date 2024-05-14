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
from starkware.starknet.common.syscalls import get_caller_address

// Local dependencies
from kakarot.library import Kakarot
from kakarot.events import evm_contract_deployed
from kakarot.interpreter import Interpreter
from kakarot.account import Account
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.storages import (
    Kakarot_native_token_address,
    Kakarot_account_contract_class_hash,
    Kakarot_uninitialized_account_class_hash,
    Kakarot_cairo1_helpers_class_hash,
    Kakarot_coinbase,
    Kakarot_block_gas_limit,
    Kakarot_evm_to_starknet_address,
)
from kakarot.kakarot import (
    constructor,
    get_account_contract_class_hash,
    get_cairo1_helpers_class_hash,
    get_native_token,
)
from backend.starknet import Starknet, Internals as StarknetInternals
from utils.dict import dict_keys, dict_values
from utils.utils import Helpers

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
    // Deploy target account
    let evm_address = env.origin;
    let starknet_address = Account.compute_starknet_address(evm_address);
    tempvar address = new model.Address(starknet_address, evm_address);

    // Write the valid jumpdests in the storage of the executed contract.
    // This requires the origin account to be deployed prior to the execution.
    let (valid_jumpdests_start, valid_jumpdests) = Helpers.initialize_jumpdests(
        bytecode_len, bytecode
    );
    StarknetInternals._save_valid_jumpdests(
        starknet_address, valid_jumpdests_start, valid_jumpdests
    );

    let (evm, stack, memory, state, gas_used, _) = Interpreter.execute(
        env=env,
        address=address,
        is_deploy_tx=0,
        bytecode_len=bytecode_len,
        bytecode=bytecode,
        calldata_len=calldata_len,
        calldata=calldata,
        value=value,
        gas_limit=1000000,
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

@external
func deploy_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    let (starknet_address) = Starknet.deploy(evm_address);
    return (contract_address=starknet_address);
}

@view
func is_deployed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (deployed: felt) {
    let (starknet_address) = Kakarot_evm_to_starknet_address.read(evm_address);
    if (starknet_address == 0) {
        return (deployed=0);
    }
    return (deployed=1);
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

// @notice Register the calling Starknet address for the given EVM address
// @dev    Only the corresponding computed Starknet address can make this call to ensure that registered accounts are actually deployed.
// @param evm_address The EVM address of the account.
@external
func register_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) {
    alloc_locals;

    let (existing_address) = Kakarot_evm_to_starknet_address.read(evm_address);
    with_attr error_message("Kakarot: account already registered") {
        assert existing_address = 0;
    }

    let (local caller_address: felt) = get_caller_address();
    let starknet_address = Account.compute_starknet_address(evm_address);
    local starknet_address = starknet_address;

    with_attr error_message("Kakarot: Caller should be {starknet_address}, got {caller_address}") {
        assert starknet_address = caller_address;
    }

    evm_contract_deployed.emit(evm_address, starknet_address);
    Kakarot_evm_to_starknet_address.write(evm_address, starknet_address);
    return ();
}
