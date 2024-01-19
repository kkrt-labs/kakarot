// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_nn, is_not_zero
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_lt, uint256_le
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict_access import DictAccess

from kakarot.account import Account
from kakarot.constants import Constants
from kakarot.errors import Errors
from kakarot.evm import EVM
from kakarot.gas import Gas
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.precompiles.precompiles import Precompiles
from kakarot.stack import Stack
from kakarot.state import State
from utils.utils import Helpers
from utils.array import slice
from utils.bytes import (
    bytes_to_bytes8_little_endian,
    felt_to_bytes,
    felt_to_bytes20,
    uint256_to_bytes32,
)
from utils.uint256 import uint256_to_uint160

using bool = felt;

// @title System operations opcodes.
// @notice This file contains the functions to execute for system operations opcodes.
namespace SystemOperations {
    func exec_create{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let opcode_number = [evm.message.bytecode + evm.program_counter];
        let is_create2 = is_not_zero(opcode_number - 0xf0);
        let popped_len = 3 + is_create2;
        let (popped) = Stack.pop_n(3 + is_create2);

        let value = popped[0];
        let offset = popped[1];
        let size = popped[2];

        // Gas
        // + extend_memory.cost
        // + init_code_gas
        // + is_create2 * GAS_KECCAK256_WORD * call_data_words
        let memory_expansion_cost = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, size
        );
        let (calldata_words, _) = unsigned_div_rem(size.low + 31, 31);
        let init_code_gas = Gas.INIT_CODE_WORD_COST * calldata_words;
        let calldata_word_gas = is_create2 * Gas.KECCAK256_WORD * calldata_words;
        let evm = EVM.charge_gas(evm, memory_expansion_cost + init_code_gas + calldata_word_gas);
        if (evm.reverted != FALSE) {
            return evm;
        }

        // Load bytecode
        let (bytecode: felt*) = alloc();
        Memory.load_n(size.low, bytecode, offset.low);

        // Get target address
        let target_address = CreateHelper.get_evm_address(
            evm.message.address.evm, popped_len, popped, size.low, bytecode
        );

        // Get message call gas
        let (gas_limit, _) = unsigned_div_rem(evm.gas_left, 64);
        let gas_limit = evm.gas_left - gas_limit;

        if (evm.message.read_only != FALSE) {
            let evm = EVM.charge_gas(evm, gas_limit);
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        // TODO: Clear return data

        // Check sender balance and nonce
        let sender = State.get_account(evm.message.address.evm);
        let is_nonce_overflow = is_le(Constants.MAX_NONCE + 1, sender.nonce);
        let (is_balance_overflow) = uint256_lt([sender.balance], value);
        let stack_depth_limit = is_le(1024, evm.message.depth);
        if (is_nonce_overflow + is_balance_overflow + stack_depth_limit != 0) {
            Stack.push_uint128(0);
            return evm;
        }

        let evm = EVM.charge_gas(evm, gas_limit);

        // Check target account availabitliy
        let target_account = State.get_account(target_address);
        let is_collision = Account.has_code_or_nonce(target_account);
        if (is_collision != 0) {
            let sender = Account.set_nonce(sender, sender.nonce + 1);
            State.update_account(sender);
            Stack.push_uint128(0);
            return evm;
        }

        // Check code size
        let code_size_too_big = is_le(2 * Constants.MAX_CODE_SIZE + 1, size.low);
        if (code_size_too_big != FALSE) {
            let evm = EVM.charge_gas(evm, evm.gas_left + 1);
            return evm;
        }

        // Increment nonce
        let sender = Account.set_nonce(sender, sender.nonce + 1);
        State.update_account(sender);

        // Final update of calling context
        tempvar parent = new model.Parent(evm, stack, memory, state);
        let stack = Stack.init();
        let memory = Memory.init();
        let state = State.copy();

        // Create child message
        let (calldata: felt*) = alloc();
        let (valid_jumpdests_start, valid_jumpdests) = Account.get_jumpdests(
            bytecode_len=size.low, bytecode=bytecode
        );
        tempvar message = new model.Message(
            bytecode=bytecode,
            bytecode_len=size.low,
            valid_jumpdests_start=valid_jumpdests_start,
            valid_jumpdests=valid_jumpdests,
            calldata=calldata,
            calldata_len=0,
            value=value.low + value.high * 2 ** 128,
            parent=parent,
            address=target_account.address,
            read_only=FALSE,
            is_create=TRUE,
            depth=evm.message.depth + 1,
            env=evm.message.env,
        );
        let child_evm = EVM.init(message, gas_limit);
        let stack = Stack.init();

        let target_account = State.get_account(target_address);
        let target_account = Account.set_nonce(target_account, 1);
        State.update_account(target_account);

        let transfer = model.Transfer(evm.message.address, target_account.address, value);
        let success = State.add_transfer(transfer);
        if (success == 0) {
            Stack.push_uint128(0);
            return child_evm;
        }

        return child_evm;
    }

    // @notice INVALID operation.
    // @dev Equivalent to REVERT (since Byzantium fork) with 0,0 as stack parameters,
    //      except that all the gas given to the current context is consumed.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param evm The pointer to the execution context
    // @return EVM The pointer to the updated execution context.
    func exec_invalid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        let evm = EVM.charge_gas(evm, evm.gas_left);
        let (revert_reason: felt*) = alloc();
        let evm = EVM.stop(evm, 0, revert_reason, TRUE);
        return evm;
    }

    // @notice RETURN operation.
    // @dev Halt execution returning output data
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return EVM The pointer to the updated execution context.
    func exec_return{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let size = popped[1];

        let memory_expansion_cost = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, size
        );
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let (local return_data: felt*) = alloc();
        Memory.load_n(size.low, return_data, offset.low);

        let evm = EVM.stop(evm, size.low, return_data, FALSE);

        return evm;
    }

    // @notice REVERT operation.
    // @dev
    // @custom:since Byzantium
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return EVM The pointer to the updated execution context.
    func exec_revert{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let size = popped[1];

        let memory_expansion_cost = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, size
        );
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        // Load revert reason from offset
        let (return_data: felt*) = alloc();
        Memory.load_n(size.low, return_data, offset.low);

        let evm = EVM.stop(evm, size.low, return_data, TRUE);
        return evm;
    }

    // @notice CALL operation. Message call into an account.
    // @dev we don't pop the two last arguments (ret_offset and ret_size) to get
    // them at the end of the CALL. These two extra stack values need to be
    // cleard if the CALL early return without reverting (value > balance, stack
    // too deep).
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 7
    // @custom:stack_produced_elements 1
    // @return EVM The pointer to the sub context.
    func exec_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        // 1. Parse args from Stack
        // Note: We don't pop ret_offset and ret_size here but at the end of the sub context
        // See finalize_parent
        let (popped) = Stack.pop_n(5);
        let gas_param = popped[0];
        let to = uint256_to_uint160(popped[1]);
        let value = popped[2];
        let args_offset = popped + 3 * Uint256.SIZE;
        let args_size = popped + 4 * Uint256.SIZE;
        let (ret_offset) = Stack.peek(0);
        let (ret_size) = Stack.peek(1);

        // 2. Gas
        // Memory expansion cost
        let memory_expansion_cost = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // Access gas cost
        // TODO
        let access_gas_cost = 0;

        // Create gas cost
        let is_account_alive = State.is_account_alive(to);
        tempvar is_value_non_zero = is_not_zero(value.low) + is_not_zero(value.high);
        tempvar is_value_non_zero = is_not_zero(is_value_non_zero);
        let create_gas_cost = (1 - is_account_alive) * is_value_non_zero * Gas.NEW_ACCOUNT;

        // Transfer gas cost
        let transfer_gas_cost = is_value_non_zero * Gas.CALL_VALUE;

        // Charge the fixed cost of the extra_gas + memory expansion
        tempvar extra_gas = access_gas_cost + create_gas_cost + transfer_gas_cost;
        let evm = EVM.charge_gas(evm, extra_gas + memory_expansion_cost);

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);

        // Charge the fixed message call gas
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            // This EVM's stack will not be used anymore, since it reverted - no need to pop the
            // last remaining 2 values ret_offset and ret_size.
            return evm;
        }

        // Operation
        if (evm.message.read_only * is_value_non_zero != FALSE) {
            // No need to pop
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        tempvar gas_stipend = gas + is_value_non_zero * Gas.CALL_STIPEND;

        let sender = State.get_account(evm.message.address.evm);
        let (sender_balance_lt_value) = uint256_lt([sender.balance], value);
        tempvar is_max_depth_reached = 1 - is_not_zero(
            (Constants.STACK_MAX_DEPTH + 1) - evm.message.depth
        );
        tempvar is_call_invalid = sender_balance_lt_value + is_max_depth_reached;
        if (is_call_invalid != FALSE) {
            // Requires popping the returndata offset and size before pushing 0
            Stack.pop_n(2);
            Stack.push_uint128(0);
            let (return_data) = alloc();
            tempvar evm = new model.EVM(
                message=evm.message,
                return_data_len=0,
                return_data=return_data,
                program_counter=evm.program_counter,
                stopped=FALSE,
                gas_left=evm.gas_left + gas_stipend,
                reverted=FALSE,
            );
            return evm;
        }

        // TODO: fix value
        let child_evm = CallHelper.generic_call(
            evm, gas_stipend, value.low, to, to, FALSE, args_offset, args_size, ret_offset, ret_size
        );

        let transfer = model.Transfer(evm.message.address, child_evm.message.address, value);
        let success = State.add_transfer(transfer);
        if (success == 0) {
            let (revert_reason_len, revert_reason) = Errors.balanceError();
            tempvar child_evm = EVM.stop(child_evm, revert_reason_len, revert_reason, TRUE);
        } else {
            tempvar child_evm = child_evm;
        }

        return child_evm;
    }

    // @notice STATICCALL operation.
    // @dev
    // @custom:since Homestead
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 6
    // @custom:stack_produced_elements 1
    // @return EVM The pointer to the sub context.
    func exec_staticcall{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        // Stack
        let (popped) = Stack.pop_n(4);
        let gas_param = popped[0];
        let to = uint256_to_uint160(popped[1]);
        let args_offset = popped + 2 * Uint256.SIZE;
        let args_size = popped + 3 * Uint256.SIZE;
        let (ret_offset) = Stack.peek(0);
        let (ret_size) = Stack.peek(1);

        // Gas
        // Memory expansion cost
        let memory_expansion_cost = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // TODO: Access gas cost
        let access_gas_cost = 0;

        // Charge the fixed cost of the extra_gas + memory expansion
        let evm = EVM.charge_gas(evm, access_gas_cost + memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            return evm;
        }

        // Operation
        let child_evm = CallHelper.generic_call(
            evm, gas, 0, to, to, TRUE, args_offset, args_size, ret_offset, ret_size
        );

        return child_evm;
    }

    // @notice CALLCODE operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 7
    // @custom:stack_produced_elements 1
    // @return EVM The pointer to the sub context.
    func exec_callcode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        // Stack
        let (popped) = Stack.pop_n(5);
        let gas_param = popped[0];
        let code_address = uint256_to_uint160(popped[1]);
        let value = popped[2];
        let args_offset = popped + 3 * Uint256.SIZE;
        let args_size = popped + 4 * Uint256.SIZE;
        let (ret_offset) = Stack.peek(0);
        let (ret_size) = Stack.peek(1);

        tempvar is_value_non_zero = is_not_zero(value.low) + is_not_zero(value.high);
        tempvar is_value_non_zero = is_not_zero(is_value_non_zero);

        // Gas
        let memory_expansion_cost = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // Access gas cost
        // TODO
        let access_gas_cost = 0;

        // TODO: fix value when refactoring CALLs for proper gas accounting
        let transfer_gas_cost = is_value_non_zero * Gas.CALL_VALUE;

        let extra_gas = access_gas_cost + transfer_gas_cost;
        let evm = EVM.charge_gas(evm, extra_gas + memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            return evm;
        }

        tempvar gas_stipend = gas + is_value_non_zero * Gas.CALL_STIPEND;

        let sender = State.get_account(evm.message.address.evm);
        let (sender_balance_lt_value) = uint256_lt([sender.balance], value);
        tempvar is_max_depth_reached = 1 - is_not_zero(
            (Constants.STACK_MAX_DEPTH + 1) - evm.message.depth
        );
        tempvar is_call_invalid = sender_balance_lt_value + is_max_depth_reached;
        if (is_call_invalid != FALSE) {
            // Requires popping the returndata offset and size before pushing 0
            Stack.pop_n(2);
            Stack.push_uint128(0);
            let (return_data) = alloc();
            tempvar evm = new model.EVM(
                message=evm.message,
                return_data_len=0,
                return_data=return_data,
                program_counter=evm.program_counter,
                stopped=FALSE,
                gas_left=evm.gas_left + gas_stipend,
                reverted=FALSE,
            );
            return evm;
        }

        let child_evm = CallHelper.generic_call(
            evm,
            gas_stipend,
            value.low,
            evm.message.address.evm,
            code_address,
            FALSE,
            args_offset,
            args_size,
            ret_offset,
            ret_size,
        );

        return child_evm;
    }

    // @notice DELEGATECALL operation.
    // @dev
    // @custom:since Byzantium
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 6
    // @custom:stack_produced_elements 1
    // @return EVM The pointer to the sub context.
    func exec_delegatecall{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        // Stack
        let (popped) = Stack.pop_n(4);
        let gas_param = popped[0];
        let code_address = uint256_to_uint160(popped[1]);
        let args_offset = popped + 2 * Uint256.SIZE;
        let args_size = popped + 3 * Uint256.SIZE;
        let (ret_offset) = Stack.peek(0);
        let (ret_size) = Stack.peek(1);
        let to = evm.message.address.evm;

        // Gas
        // Memory expansion cost
        let memory_expansion_cost = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // TODO: Access gas cost
        let access_gas_cost = 0;

        // Charge the fixed cost of the extra_gas + memory expansion
        let extra_gas = access_gas_cost;
        let evm = EVM.charge_gas(evm, extra_gas + memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            return evm;
        }

        tempvar is_max_depth_reached = 1 - is_not_zero(
            (Constants.STACK_MAX_DEPTH + 1) - evm.message.depth
        );
        if (is_max_depth_reached != FALSE) {
            // Requires popping the returndata offset and size before pushing 0
            Stack.pop_n(2);
            Stack.push_uint128(0);
            let (return_data) = alloc();
            tempvar evm = new model.EVM(
                message=evm.message,
                return_data_len=0,
                return_data=return_data,
                program_counter=evm.program_counter,
                stopped=FALSE,
                gas_left=evm.gas_left + gas,
                reverted=FALSE,
            );
            return evm;
        }

        // Operation
        let child_evm = CallHelper.generic_call(
            evm,
            gas,
            evm.message.value,
            to,
            code_address,
            FALSE,
            args_offset,
            args_size,
            ret_offset,
            ret_size,
        );

        return child_evm;
    }

    // @notice SELFDESTRUCT operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 3000 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @return EVM The pointer to the updated execution_context.
    func exec_selfdestruct{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        if (evm.message.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        // Transfer funds
        let (popped) = Stack.pop();
        let recipient_evm_address = uint256_to_uint160([popped]);

        // Remove this when https://eips.ethereum.org/EIPS/eip-6780 is validated
        if (recipient_evm_address == evm.message.address.evm) {
            tempvar is_recipient_self = TRUE;
        } else {
            tempvar is_recipient_self = FALSE;
        }
        let recipient_evm_address = (1 - is_recipient_self) * recipient_evm_address;

        let recipient_starknet_address = Account.compute_starknet_address(recipient_evm_address);
        tempvar recipient = new model.Address(
            starknet=recipient_starknet_address, evm=recipient_evm_address
        );
        let account = State.get_account(evm.message.address.evm);
        let transfer = model.Transfer(
            sender=account.address, recipient=recipient, amount=[account.balance]
        );
        let success = State.add_transfer(transfer);

        // Register for SELFDESTRUCT
        // @dev: get_account again because add_transfer updated it
        let account = State.get_account(evm.message.address.evm);
        let account = Account.selfdestruct(account);
        State.update_account(account);

        // Halt context
        let (return_data: felt*) = alloc();
        let evm = EVM.stop(evm, 0, return_data, FALSE);

        return evm;
    }
}

namespace CallHelper {
    // @notice The shared logic of the CALL, CALLCODE, STATICCALL, and DELEGATECALL ops.
    // Loads the calldata from memory, executes the precompiles if the target is one, otherwise
    // constructs the child evm corresponding to the new execution frame of the call and returns it.
    // @param evm The current EVM, which is the parent of the new EVM.
    // @param gas The gas to be used by the new EVM.
    // @param value The value to be transferred in the call
    // @param to The address of the target account.
    // @param code_address The address of the account whose code will be executed.
    // @param is_staticcall A boolean indicating whether the call is a static call.
    // @param args_offset The offset of the calldata in memory.
    // @param args_size The size of the calldata in memory.
    // @param ret_offset The offset to store the return data at.
    // @param ret_size The size of the return data.
    // @return EVM The pointer to the newly created sub context.
    func generic_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(
        evm: model.EVM*,
        gas: felt,
        value: felt,
        to: felt,
        code_address: felt,
        is_staticcall: bool,
        args_offset: Uint256*,
        args_size: Uint256*,
        ret_offset: Uint256*,
        ret_size: Uint256*,
    ) -> model.EVM* {
        alloc_locals;

        // 1. Calldata
        let (calldata: felt*) = alloc();
        Memory.load_n(args_size.low, calldata, args_offset.low);

        // 2. Build child_evm
        // Check if the called address is a precompiled contract
        let is_precompile = Precompiles.is_precompile(address=code_address);
        if (is_precompile != FALSE) {
            tempvar parent = new model.Parent(evm, stack, memory, state);
            let child_evm = Precompiles.run(
                evm_address=code_address,
                calldata_len=args_size.low,
                calldata=calldata,
                value=value,
                parent=parent,
                gas_left=gas,
            );

            return child_evm;
        }

        let code_account = State.get_account(code_address);
        local code_len: felt = code_account.code_len;
        local code: felt* = code_account.code;

        let to_starknet_address = Account.compute_starknet_address(to);
        tempvar to_address = new model.Address(starknet=to_starknet_address, evm=to);

        tempvar parent = new model.Parent(evm, stack, memory, state);
        let stack = Stack.init();
        let memory = Memory.init();
        let (valid_jumpdests_start, valid_jumpdests) = Account.get_jumpdests(
            bytecode_len=code_len, bytecode=code
        );

        if (is_staticcall != FALSE) {
            tempvar read_only = TRUE;
        } else {
            tempvar read_only = evm.message.read_only;
        }

        tempvar message = new model.Message(
            bytecode=code,
            bytecode_len=code_len,
            valid_jumpdests_start=valid_jumpdests_start,
            valid_jumpdests=valid_jumpdests,
            calldata=calldata,
            calldata_len=args_size.low,
            value=value,
            parent=parent,
            address=to_address,
            read_only=read_only,
            is_create=FALSE,
            depth=evm.message.depth + 1,
            env=evm.message.env,
        );

        let child_evm = EVM.init(message, gas);
        let state = State.copy();
        return child_evm;
    }

    // @return EVM The pointer to the updated calling context.
    func finalize_parent{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        // Pop ret_offset and ret_size
        // See call family opcodes who don't pop these
        // two values, the Stack here is guaranteed to have enough items
        // values are checked there as Memory expansion cost is computed there.
        let (popped) = Stack.pop_n(n=2);
        let ret_offset = popped[0];
        let ret_size = popped[1];

        // Put status in stack
        Stack.push_uint128(1 - evm.reverted);

        // Store RETURN_DATA in memory
        let (return_data: felt*) = alloc();
        slice(return_data, evm.return_data_len, evm.return_data, 0, ret_size.low);
        Memory.store_n(ret_size.low, return_data, ret_offset.low);

        // Gas not used is returned when evm is not reverted
        local gas_left;
        if (evm.reverted == FALSE) {
            assert gas_left = evm.message.parent.evm.gas_left + evm.gas_left;
        } else {
            assert gas_left = evm.message.parent.evm.gas_left;
        }

        tempvar evm = new model.EVM(
            message=evm.message.parent.evm.message,
            return_data_len=evm.return_data_len,
            return_data=evm.return_data,
            program_counter=evm.message.parent.evm.program_counter + 1,
            stopped=evm.message.parent.evm.stopped,
            gas_left=gas_left,
            reverted=evm.message.parent.evm.reverted,
        );

        return evm;
    }
}

namespace CreateHelper {
    // @notice Constructs an evm contract address for the create opcode
    //         via last twenty bytes of the keccak hash of:
    //         keccak256(rlp([sender_address,sender_nonce])).
    //         See [CREATE](https://www.evm.codes/#f0).
    // @param sender_address The evm sender address.
    // @param bytecode_len The length of the initialization code.
    // @param nonce The nonce given to the create opcode.
    // @return EVM The pointer to the updated calling context.
    func get_create_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(sender_address: felt, nonce: felt) -> (evm_contract_address: felt) {
        alloc_locals;
        local message_len;
        // rlp([address, nonce]) inlined to save unnecessary expensive general RLP encoding
        // final bytes is either
        // (0xc0 + bytes_lenght) + (0x80 + 20) + address + nonce
        // or
        // (0xc0 + bytes_lenght) + (0x80 + 20) + address + (0x80 + nonce_len) + nonce
        let (message: felt*) = alloc();
        assert [message + 1] = 0x80 + 20;
        felt_to_bytes20(message + 2, sender_address);
        let encode_nonce = is_le(0x80, nonce);
        if (encode_nonce != FALSE) {
            let nonce_len = felt_to_bytes(message + 2 + 20 + 1, nonce);
            assert [message + 2 + 20] = 0x80 + nonce_len;
            assert message_len = 1 + 1 + 20 + 1 + nonce_len;
        } else {
            let is_nonce_not_zero = is_not_zero(nonce);
            let encoded_nonce = nonce * is_nonce_not_zero + (1 - is_nonce_not_zero) * 0x80;
            assert [message + 2 + 20] = encoded_nonce;
            assert message_len = 1 + 1 + 20 + 1;
        }
        assert message[0] = message_len + 0xc0 - 1;

        let (message_bytes8: felt*) = alloc();
        bytes_to_bytes8_little_endian(message_bytes8, message_len, message);

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;
        with keccak_ptr {
            let (message_hash) = cairo_keccak_bigend(message_bytes8, message_len);
        }

        finalize_keccak(keccak_ptr_start, keccak_ptr);

        let address = uint256_to_uint160(message_hash);
        return (address,);
    }

    // @notice Constructs an evm contract address for the create2 opcode
    //         via last twenty bytes of the keccak hash of:
    //         keccak256(0xff + sender_address + salt +
    //         keccak256(initialization_code))[12:].
    //         See [CREATE2](https://www.evm.codes/#f5).
    // @param sender_address The evm sender address.
    // @param bytecode_len The length of the initialization code.
    // @param bytecode The offset to store the element at.
    // @param salt The salt given to the create2 opcode.
    // @return EVM The pointer to the updated calling context.
    func get_create2_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(sender_address: felt, bytecode_len: felt, bytecode: felt*, salt: Uint256) -> (
        evm_contract_address: felt
    ) {
        alloc_locals;
        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        let (local bytecode_bytes8: felt*) = alloc();
        bytes_to_bytes8_little_endian(bytecode_bytes8, bytecode_len, bytecode);
        with keccak_ptr {
            let (bytecode_hash) = cairo_keccak_bigend(bytecode_bytes8, bytecode_len);
        }

        // get keccak hash of
        // marker + caller_address + salt + bytecode_hash
        let (local packed_bytes: felt*) = alloc();

        // 0xff is by convention the marker involved in deterministic address creation for create2
        assert [packed_bytes] = 0xff;
        felt_to_bytes20(packed_bytes + 1, sender_address);
        uint256_to_bytes32(packed_bytes + 1 + 20, salt);
        uint256_to_bytes32(packed_bytes + 1 + 20 + 32, bytecode_hash);
        let packed_bytes_len = 1 + 20 + 32 + 32;

        let (local packed_bytes8: felt*) = alloc();
        bytes_to_bytes8_little_endian(packed_bytes8, packed_bytes_len, packed_bytes);

        with keccak_ptr {
            let (create2_hash) = cairo_keccak_bigend(packed_bytes8, packed_bytes_len);
        }

        finalize_keccak(keccak_ptr_start, keccak_ptr);

        let create2_address = uint256_to_uint160(create2_hash);
        return (create2_address,);
    }

    // @notice Pre-compute the evm address of a contract account before deploying it.
    func get_evm_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        state: model.State*,
    }(
        evm_address: felt, popped_len: felt, popped: Uint256*, bytecode_len: felt, bytecode: felt*
    ) -> felt {
        alloc_locals;
        // create2 context pops 4 off the stack, create pops 3
        // so we use popped_len to derive the way we should handle
        // the creation of evm addresses
        if (popped_len != 4) {
            let account = State.get_account(evm_address);
            let (evm_contract_address) = CreateHelper.get_create_address(
                evm_address, account.nonce
            );
            return evm_contract_address;
        } else {
            let salt = popped[3];
            let (evm_contract_address) = CreateHelper.get_create2_address(
                sender_address=evm_address, bytecode_len=bytecode_len, bytecode=bytecode, salt=salt
            );
            return evm_contract_address;
        }
    }

    // @notice At the end of a sub-context initiated with CREATE or CREATE2, the calling context's stack is updated.
    // @param evm The pointer to the calling context.
    // @return EVM The pointer to the updated calling context.
    func finalize_parent{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        // Charge final deposit gas
        let code_size_limit = is_le(evm.return_data_len, Constants.MAX_CODE_SIZE);
        let code_deposit_cost = Gas.CODE_DEPOSIT * evm.return_data_len;
        let remaining_gas = evm.gas_left - code_deposit_cost;
        let enough_gas = is_nn(remaining_gas);
        let success = (1 - evm.reverted) * enough_gas * code_size_limit;

        // Stack output: the address of the deployed contract, 0 if the deployment failed.
        let (address_high, address_low) = split_felt(evm.message.address.evm * success);
        tempvar address = new Uint256(low=address_low, high=address_high);

        Stack.push(address);

        if (success == FALSE) {
            // REVERTED, just returns previous EVM
            tempvar evm = new model.EVM(
                message=evm.message.parent.evm.message,
                return_data_len=evm.return_data_len,
                return_data=evm.return_data,
                program_counter=evm.message.parent.evm.program_counter + 1,
                stopped=evm.message.parent.evm.stopped,
                gas_left=evm.message.parent.evm.gas_left,
                reverted=evm.message.parent.evm.reverted,
            );
            return evm;
        }

        // Write bytecode to Account
        let account = State.get_account(evm.message.address.evm);
        let account = Account.set_code(account, evm.return_data_len, evm.return_data);
        State.update_account(account);

        tempvar evm = new model.EVM(
            message=evm.message.parent.evm.message,
            return_data_len=evm.return_data_len,
            return_data=evm.return_data,
            program_counter=evm.message.parent.evm.program_counter + 1,
            stopped=evm.message.parent.evm.stopped,
            gas_left=evm.message.parent.evm.gas_left + remaining_gas,
            reverted=evm.message.parent.evm.reverted,
        );

        return evm;
    }
}
