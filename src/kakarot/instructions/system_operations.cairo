// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_nn, is_not_zero
from starkware.cairo.common.memset import memset
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_secp.signature import recover_public_key
from starkware.cairo.common.cairo_secp.ec_point import EcPoint
from starkware.cairo.common.cairo_secp.bigint import uint256_to_bigint
from starkware.cairo.common.cairo_secp.bigint3 import BigInt3
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_lt, uint256_le
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict_access import DictAccess

from kakarot.account import Account
from kakarot.interfaces.interfaces import IAccount, ICairo1Helpers
from kakarot.constants import Constants
from kakarot.errors import Errors
from kakarot.evm import EVM
from kakarot.gas import Gas
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.storages import Kakarot_cairo1_helpers_class_hash
from kakarot.state import State
from kakarot.precompiles.ec_recover import EcRecoverHelpers
from utils.utils import Helpers
from utils.array import slice, pad_end
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

        let value = popped;
        let offset = popped[1];
        let size = popped[2];

        // Gas
        // + extend_memory.cost
        // + init_code_gas
        // + is_create2 * GAS_KECCAK256_WORD * call_data_words
        let memory_expansion = Gas.memory_expansion_cost_saturated(memory.words_len, offset, size);
        let (calldata_words, _) = unsigned_div_rem(size.low + 31, 32);
        let init_code_gas_low = Gas.INIT_CODE_WORD_COST * calldata_words;
        tempvar init_code_gas_high = is_not_zero(size.high) * 2 ** 128;
        let calldata_word_gas = is_create2 * Gas.KECCAK256_WORD * calldata_words;
        let evm = EVM.charge_gas(
            evm, memory_expansion.cost + init_code_gas_low + init_code_gas_high + calldata_word_gas
        );
        if (evm.reverted != FALSE) {
            return evm;
        }

        // Load bytecode
        tempvar memory = new model.Memory(
            word_dict_start=memory.word_dict_start,
            word_dict=memory.word_dict,
            memory_expansion.new_words_len,
        );
        let (bytecode: felt*) = alloc();
        Memory.load_n(size.low, bytecode, offset.low);

        let (return_data) = alloc();

        tempvar evm = new model.EVM(
            message=evm.message,
            return_data_len=0,
            return_data=return_data,
            program_counter=evm.program_counter,
            stopped=evm.stopped,
            gas_left=evm.gas_left,
            gas_refund=evm.gas_refund,
            reverted=evm.reverted,
        );

        let target_address = CreateHelper.get_evm_address(
            evm.message.address.evm, popped_len, popped, size.low, bytecode
        );

        // @dev: performed before eventual subsequent early-returns of this function
        // to mark the account as warm EIP-2929
        let target_account = State.get_account(target_address);

        // Get message call gas
        let (gas_limit, _) = unsigned_div_rem(evm.gas_left, 64);
        let gas_limit = evm.gas_left - gas_limit;

        if (evm.message.read_only != FALSE) {
            let evm = EVM.charge_gas(evm, gas_limit);
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
            return evm;
        }

        // Check sender balance and nonce
        let sender = State.get_account(evm.message.address.evm);
        let is_nonce_overflow = Helpers.is_zero(Constants.MAX_NONCE - sender.nonce);
        let (is_balance_overflow) = uint256_lt([sender.balance], [value]);
        let stack_depth_limit = Helpers.is_zero(Constants.STACK_MAX_DEPTH - evm.message.depth);
        if (is_nonce_overflow + is_balance_overflow + stack_depth_limit != 0) {
            Stack.push_uint128(0);
            return evm;
        }

        let evm = EVM.charge_gas(evm, gas_limit);

        // Operation
        // Check target account availability
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
        tempvar authorized = new model.Option(is_some=0, value=0);
        tempvar message = new model.Message(
            bytecode=bytecode,
            bytecode_len=size.low,
            valid_jumpdests_start=valid_jumpdests_start,
            valid_jumpdests=valid_jumpdests,
            calldata=calldata,
            calldata_len=0,
            value=value,
            caller=evm.message.address.evm,
            parent=parent,
            address=target_account.address,
            code_address=0,
            read_only=FALSE,
            is_create=TRUE,
            authorized=authorized,
            depth=evm.message.depth + 1,
            env=evm.message.env,
        );
        let child_evm = EVM.init(message, gas_limit);
        let stack = Stack.init();

        let target_account = State.get_account(target_address);
        let target_account = Account.set_nonce(target_account, 1);
        State.update_account(target_account);

        let transfer = model.Transfer(evm.message.address, target_account.address, [value]);
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
        let (revert_reason: felt*) = alloc();
        tempvar evm = new model.EVM(
            message=evm.message,
            return_data_len=0,
            return_data=revert_reason,
            program_counter=evm.program_counter,
            stopped=TRUE,
            gas_left=0,
            gas_refund=evm.gas_refund,
            reverted=Errors.EXCEPTIONAL_HALT,
        );
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

        let memory_expansion = Gas.memory_expansion_cost_saturated(memory.words_len, offset, size);
        let evm = EVM.charge_gas(evm, memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        tempvar memory = new model.Memory(
            word_dict_start=memory.word_dict_start,
            word_dict=memory.word_dict,
            memory_expansion.new_words_len,
        );
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

        let memory_expansion = Gas.memory_expansion_cost_saturated(memory.words_len, offset, size);
        let evm = EVM.charge_gas(evm, memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        // Load revert reason from offset
        let (return_data: felt*) = alloc();
        tempvar memory = new model.Memory(
            word_dict_start=memory.word_dict_start,
            word_dict=memory.word_dict,
            memory_expansion.new_words_len,
        );
        Memory.load_n(size.low, return_data, offset.low);

        let evm = EVM.stop(evm, size.low, return_data, Errors.REVERT);
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
        let value = popped + 2 * Uint256.SIZE;
        let args_offset = popped + 3 * Uint256.SIZE;
        let args_size = popped + 4 * Uint256.SIZE;
        let (ret_offset) = Stack.peek(0);
        let (ret_size) = Stack.peek(1);

        local call_sender = evm.message.address.evm;

        // 2. Gas
        // Memory expansion cost
        let memory_expansion = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // Access gas cost. The account is marked as warm in the `generic_call` function,
        // which performs a `get_account`.
        let is_account_warm = State.is_account_warm(to);
        tempvar access_gas_cost = is_account_warm * Gas.WARM_ACCESS + (1 - is_account_warm) *
            Gas.COLD_ACCOUNT_ACCESS;

        // Create gas cost
        let is_account_alive = State.is_account_alive(to);
        tempvar is_value_non_zero = is_not_zero(value.low) + is_not_zero(value.high);
        tempvar is_value_non_zero = is_not_zero(is_value_non_zero);
        let create_gas_cost = (1 - is_account_alive) * is_value_non_zero * Gas.NEW_ACCOUNT;

        // Transfer gas cost
        let transfer_gas_cost = is_value_non_zero * Gas.CALL_VALUE;

        // Charge the fixed cost of the extra_gas + memory expansion
        tempvar extra_gas = access_gas_cost + create_gas_cost + transfer_gas_cost;
        let evm = EVM.charge_gas(evm, extra_gas + memory_expansion.cost);

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);

        // Charge the fixed message call gas
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            // This EVM's stack will not be used anymore, since it reverted - no need to pop the
            // last remaining 2 values ret_offset and ret_size.
            return evm;
        }

        // Operation
        tempvar memory = new model.Memory(
            memory.word_dict_start, memory.word_dict, memory_expansion.new_words_len
        );
        if (evm.message.read_only * is_value_non_zero != FALSE) {
            // No need to pop
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
            return evm;
        }

        tempvar gas_with_stipend = gas + is_value_non_zero * Gas.CALL_STIPEND;

        let sender = State.get_account(call_sender);
        let (sender_balance_lt_value) = uint256_lt([sender.balance], [value]);
        tempvar is_max_depth_reached = Helpers.is_zero(
            Constants.STACK_MAX_DEPTH - evm.message.depth
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
                gas_left=evm.gas_left + gas_with_stipend,
                gas_refund=evm.gas_refund,
                reverted=FALSE,
            );
            return evm;
        }

        let child_evm = CallHelper.generic_call(
            evm,
            gas=gas_with_stipend,
            value=value,
            caller=call_sender,
            to=to,
            code_address=to,
            is_staticcall=FALSE,
            args_offset=args_offset,
            args_size=args_size,
            ret_offset=ret_offset,
            ret_size=ret_size,
        );

        let transfer = model.Transfer(evm.message.address, child_evm.message.address, [value]);
        let success = State.add_transfer(transfer);
        if (success == 0) {
            let (revert_reason_len, revert_reason) = Errors.balanceError();
            tempvar child_evm = EVM.stop(
                child_evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT
            );
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

        local call_sender = evm.message.address.evm;

        // Gas
        // Memory expansion cost
        let memory_expansion = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // Access gas cost. The account is marked as warm in the `is_account_alive` instruction,
        // which performs a `get_account`.
        let is_account_warm = State.is_account_warm(to);
        tempvar access_gas_cost = is_account_warm * Gas.WARM_ACCESS + (1 - is_account_warm) *
            Gas.COLD_ACCOUNT_ACCESS;

        // Charge the fixed cost of the extra_gas + memory expansion
        let evm = EVM.charge_gas(evm, access_gas_cost + memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            return evm;
        }

        // Operation
        tempvar memory = new model.Memory(
            memory.word_dict_start, memory.word_dict, memory_expansion.new_words_len
        );
        tempvar is_max_depth_reached = Helpers.is_zero(
            Constants.STACK_MAX_DEPTH - evm.message.depth
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
                gas_refund=evm.gas_refund,
                reverted=FALSE,
            );
            return evm;
        }

        tempvar zero = new Uint256(0, 0);
        // Operation
        let child_evm = CallHelper.generic_call(
            evm,
            gas,
            value=zero,
            caller=call_sender,
            to=to,
            code_address=to,
            is_staticcall=TRUE,
            args_offset=args_offset,
            args_size=args_size,
            ret_offset=ret_offset,
            ret_size=ret_size,
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
        let value = popped + 2 * Uint256.SIZE;
        let args_offset = popped + 3 * Uint256.SIZE;
        let args_size = popped + 4 * Uint256.SIZE;
        let (ret_offset) = Stack.peek(0);
        let (ret_size) = Stack.peek(1);

        local call_sender = evm.message.address.evm;

        // Gas
        let memory_expansion = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // Access gas cost. The account is marked as warm in the `is_account_alive` instruction,
        // which performs a `get_account`.
        let is_account_warm = State.is_account_warm(code_address);
        tempvar access_gas_cost = is_account_warm * Gas.WARM_ACCESS + (1 - is_account_warm) *
            Gas.COLD_ACCOUNT_ACCESS;

        tempvar is_value_non_zero = is_not_zero(value.low) + is_not_zero(value.high);
        tempvar is_value_non_zero = is_not_zero(is_value_non_zero);
        let transfer_gas_cost = is_value_non_zero * Gas.CALL_VALUE;

        let extra_gas = access_gas_cost + transfer_gas_cost;
        let evm = EVM.charge_gas(evm, extra_gas + memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            return evm;
        }
        tempvar gas_with_stipend = gas + is_value_non_zero * Gas.CALL_STIPEND;

        // Operation
        tempvar memory = new model.Memory(
            memory.word_dict_start, memory.word_dict, memory_expansion.new_words_len
        );
        let sender = State.get_account(call_sender);
        let (sender_balance_lt_value) = uint256_lt([sender.balance], [value]);
        tempvar is_max_depth_reached = Helpers.is_zero(
            Constants.STACK_MAX_DEPTH - evm.message.depth
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
                gas_left=evm.gas_left + gas_with_stipend,
                gas_refund=evm.gas_refund,
                reverted=FALSE,
            );
            return evm;
        }

        let child_evm = CallHelper.generic_call(
            evm,
            gas=gas_with_stipend,
            value=value,
            caller=call_sender,
            to=call_sender,
            code_address=code_address,
            is_staticcall=FALSE,
            args_offset=args_offset,
            args_size=args_size,
            ret_offset=ret_offset,
            ret_size=ret_size,
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

        let call_sender = evm.message.caller;
        let to = evm.message.address.evm;

        // Gas
        // Memory expansion cost
        let memory_expansion = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // Access gas cost. The account is marked as warm in the `generic_call` function,
        // which performs a `get_account`.
        let is_account_warm = State.is_account_warm(code_address);
        tempvar access_gas_cost = is_account_warm * Gas.WARM_ACCESS + (1 - is_account_warm) *
            Gas.COLD_ACCOUNT_ACCESS;

        // Charge the fixed cost of the extra_gas + memory expansion
        let extra_gas = access_gas_cost;
        let evm = EVM.charge_gas(evm, extra_gas + memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            return evm;
        }

        tempvar is_max_depth_reached = Helpers.is_zero(
            Constants.STACK_MAX_DEPTH - evm.message.depth
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
                gas_refund=evm.gas_refund,
                reverted=FALSE,
            );
            return evm;
        }

        // Operation
        tempvar memory = new model.Memory(
            memory.word_dict_start, memory.word_dict, memory_expansion.new_words_len
        );
        let child_evm = CallHelper.generic_call(
            evm,
            gas,
            value=evm.message.value,
            caller=call_sender,
            to=to,
            code_address=code_address,
            is_staticcall=FALSE,
            args_offset=args_offset,
            args_size=args_size,
            ret_offset=ret_offset,
            ret_size=ret_size,
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
        let (popped) = Stack.pop();
        let recipient = uint256_to_uint160([popped]);

        // Gas
        // Access gas cost. The account is marked as warm in the `is_account_alive` instruction,
        // which performs a `get_account` and thus must be performed after the warm check.
        let is_recipient_warm = State.is_account_warm(recipient);
        tempvar access_gas_cost = (1 - is_recipient_warm) * Gas.COLD_ACCOUNT_ACCESS;

        let is_recipient_alive = State.is_account_alive(recipient);
        let self_account = State.get_account(evm.message.address.evm);
        tempvar is_self_balance_zero = Helpers.is_zero(self_account.balance.low) * Helpers.is_zero(
            self_account.balance.high
        );
        tempvar gas_selfdestruct_new_account = (1 - is_recipient_alive) * (
            1 - is_self_balance_zero
        ) * Gas.SELF_DESTRUCT_NEW_ACCOUNT;

        let evm = EVM.charge_gas(evm, access_gas_cost + gas_selfdestruct_new_account);
        if (evm.reverted != FALSE) {
            return evm;
        }

        // Operation
        if (evm.message.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
            return evm;
        }

        // If the account was created in the same transaction and recipient is self, the native token is burnt
        tempvar is_recipient_not_self = is_not_zero(recipient - evm.message.address.evm);

        if (self_account.created != FALSE) {
            tempvar recipient = is_recipient_not_self * recipient;
        } else {
            tempvar recipient = recipient;
        }

        let recipient_account = State.get_account(recipient);
        let transfer = model.Transfer(
            sender=self_account.address,
            recipient=recipient_account.address,
            amount=[self_account.balance],
        );
        let success = State.add_transfer(transfer);

        // Marked as SELFDESTRUCT for commitment
        // @dev: get_account again because add_transfer updated it
        let account = State.get_account(evm.message.address.evm);
        let account = Account.selfdestruct(account);
        State.update_account(account);

        // Halt context
        let (return_data: felt*) = alloc();
        let evm = EVM.stop(evm, 0, return_data, FALSE);

        return evm;
    }

    func exec_auth{
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
        let (popped) = Stack.pop_n(3);
        let authority = uint256_to_uint160(popped[0]);
        let offset = popped[1];
        let length = popped[2];

        // Gas
        // Calling `get_account` subsequently will make the account warm for the next interaction
        let is_warm = State.is_account_warm(authority);
        tempvar access_gas_cost = is_warm * Gas.WARM_ACCESS + (1 - is_warm) *
            Gas.COLD_ACCOUNT_ACCESS;

        // Charge memory access gas - will revert if offset.high | length.high != 0
        let memory_expansion = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, length
        );
        let evm = EVM.charge_gas(evm, memory_expansion.cost + access_gas_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        // OPERATION
        tempvar memory = new model.Memory(
            word_dict_start=memory.word_dict_start,
            word_dict=memory.word_dict,
            words_len=memory_expansion.new_words_len,
        );

        // authority not EOA
        let authority_account = State.get_account(authority);
        if (authority_account.code_len != 0) {
            Stack.push_uint128(0);
            tempvar authorized = new model.Option(is_some=0, value=0);
            tempvar message = new model.Message(
                bytecode=evm.message.bytecode,
                bytecode_len=evm.message.bytecode_len,
                valid_jumpdests_start=evm.message.valid_jumpdests_start,
                valid_jumpdests=evm.message.valid_jumpdests,
                calldata=evm.message.calldata,
                calldata_len=evm.message.calldata_len,
                value=evm.message.value,
                caller=evm.message.caller,
                parent=evm.message.parent,
                address=evm.message.address,
                code_address=evm.message.code_address,
                read_only=evm.message.read_only,
                is_create=evm.message.is_create,
                authorized=authorized,
                depth=evm.message.depth,
                env=evm.message.env,
            );
            return new model.EVM(
                message=message,
                return_data_len=evm.return_data_len,
                return_data=evm.return_data,
                program_counter=evm.program_counter,
                stopped=evm.stopped,
                gas_left=evm.gas_left,
                gas_refund=evm.gas_refund,
                reverted=evm.reverted,
            );
        }

        let (mem_slice) = alloc();
        let mem_slice_len = length.low;
        Memory.load_n(mem_slice_len, mem_slice, offset.low);

        // Pad the memory slice with zeros to a size of 97
        pad_end(mem_slice_len, mem_slice, 97);

        // The first 65 bytes hold the Signature {y_parity, r, s}
        let y_parity = mem_slice[0];
        let r = Helpers.bytes32_to_uint256(mem_slice + 1);
        let s = Helpers.bytes32_to_uint256(mem_slice + 33);

        // Build the original message to compute the hash and verify the sig
        let (msg) = alloc();
        assert msg[0] = Constants.MAGIC;
        Helpers.split_word(evm.message.env.chain_id, 32, msg + 1);
        Helpers.split_word(authority_account.nonce, 32, msg + 33);
        Helpers.split_word(evm.message.address.evm, 32, msg + 65);
        // copy the commit to msg, held in mem_slice[65, 97]
        memcpy(msg + 97, mem_slice + 65, 32);
        let message_len = 129;

        let (message_bytes8: felt*) = alloc();
        let (message_bytes8_len, last_word, last_word_num_bytes) = bytes_to_bytes8_little_endian(
            message_bytes8, message_len, msg
        );

        let (helpers_class) = Kakarot_cairo1_helpers_class_hash.read();
        let (msg_hash) = ICairo1Helpers.library_call_keccak(
            class_hash=helpers_class,
            words_len=message_bytes8_len,
            words=message_bytes8,
            last_input_word=last_word,
            last_input_num_bytes=last_word_num_bytes,
        );

        let (msg_hash_bigint: BigInt3) = uint256_to_bigint(msg_hash);
        let (r_bigint: BigInt3) = uint256_to_bigint(r);
        let (s_bigint: BigInt3) = uint256_to_bigint(s);
        let (public_key_point: EcPoint) = recover_public_key(
            msg_hash=msg_hash_bigint, r=r_bigint, s=s_bigint, v=y_parity
        );
        let (calculated_eth_address) = EcRecoverHelpers.public_key_point_to_eth_address(
            public_key_point=public_key_point, helpers_class=helpers_class
        );

        if (calculated_eth_address != authority) {
            Stack.push_uint128(0);
            return evm;
        }

        Stack.push_uint128(1);
        tempvar authorized = new model.Option(is_some=1, value=authority);
        tempvar message = new model.Message(
            bytecode=evm.message.bytecode,
            bytecode_len=evm.message.bytecode_len,
            valid_jumpdests_start=evm.message.valid_jumpdests_start,
            valid_jumpdests=evm.message.valid_jumpdests,
            calldata=evm.message.calldata,
            calldata_len=evm.message.calldata_len,
            value=evm.message.value,
            caller=evm.message.caller,
            parent=evm.message.parent,
            address=evm.message.address,
            code_address=evm.message.code_address,
            read_only=evm.message.read_only,
            is_create=evm.message.is_create,
            authorized=authorized,
            depth=evm.message.depth,
            env=evm.message.env,
        );

        return new model.EVM(
            message=message,
            return_data_len=evm.return_data_len,
            return_data=evm.return_data,
            program_counter=evm.program_counter,
            stopped=evm.stopped,
            gas_left=evm.gas_left,
            gas_refund=evm.gas_refund,
            reverted=evm.reverted,
        );
    }

    func exec_authcall{
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
        let value = popped + 2 * Uint256.SIZE;
        let args_offset = popped + 3 * Uint256.SIZE;
        let args_size = popped + 4 * Uint256.SIZE;
        let (ret_offset) = Stack.peek(0);
        let (ret_size) = Stack.peek(1);

        local call_sender = evm.message.authorized.value;

        // 2. Gas
        // Memory expansion cost
        let memory_expansion = Gas.max_memory_expansion_cost(
            memory.words_len, args_offset, args_size, ret_offset, ret_size
        );

        // Access gas cost. The account is marked as warm in the `generic_call` function,
        // which performs a `get_account`.
        let is_account_warm = State.is_account_warm(to);
        tempvar access_gas_cost = is_account_warm * Gas.WARM_ACCESS + (1 - is_account_warm) *
            Gas.COLD_ACCOUNT_ACCESS;

        // Create gas cost
        let is_account_alive = State.is_account_alive(to);
        tempvar is_value_non_zero = is_not_zero(value.low) + is_not_zero(value.high);
        tempvar is_value_non_zero = is_not_zero(is_value_non_zero);
        let create_gas_cost = (1 - is_account_alive) * is_value_non_zero * Gas.NEW_ACCOUNT;

        // Transfer gas cost
        let transfer_gas_cost = is_value_non_zero * Gas.AUTHCALL_VALUE;

        // Charge the fixed cost of the extra_gas + memory expansion
        tempvar extra_gas = access_gas_cost + create_gas_cost + transfer_gas_cost;
        let evm = EVM.charge_gas(evm, extra_gas + memory_expansion.cost);

        let gas = Gas.compute_message_call_gas(gas_param, evm.gas_left);

        // Charge the fixed message call gas
        let evm = EVM.charge_gas(evm, gas);
        if (evm.reverted != FALSE) {
            // This EVM's stack will not be used anymore, since it reverted - no need to pop the
            // last remaining 2 values ret_offset and ret_size.
            return evm;
        }

        // Operation
        tempvar memory = new model.Memory(
            memory.word_dict_start, memory.word_dict, memory_expansion.new_words_len
        );
        if (evm.message.read_only * is_value_non_zero != FALSE) {
            // No need to pop
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
            return evm;
        }

        let is_authorized_unset = 1 - evm.message.authorized.is_some;
        let sender = State.get_account(call_sender);
        let (sender_balance_lt_value) = uint256_lt([sender.balance], [value]);
        tempvar is_max_depth_reached = Helpers.is_zero(
            Constants.STACK_MAX_DEPTH - evm.message.depth
        );
        tempvar is_call_invalid = sender_balance_lt_value + is_max_depth_reached +
            is_authorized_unset;
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
                gas_left=evm.gas_left + gas,
                gas_refund=evm.gas_refund,
                reverted=FALSE,
            );
            return evm;
        }

        let child_evm = CallHelper.generic_call(
            evm,
            gas=gas,
            value=value,
            caller=call_sender,
            to=to,
            code_address=to,
            is_staticcall=FALSE,
            args_offset=args_offset,
            args_size=args_size,
            ret_offset=ret_offset,
            ret_size=ret_size,
        );

        let call_sender_starknet_address = Account.compute_starknet_address(call_sender);
        tempvar call_sender_address = new model.Address(
            starknet=call_sender_starknet_address, evm=call_sender
        );
        let transfer = model.Transfer(call_sender_address, child_evm.message.address, [value]);
        let success = State.add_transfer(transfer);
        if (success == 0) {
            let (revert_reason_len, revert_reason) = Errors.balanceError();
            tempvar child_evm = EVM.stop(
                child_evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT
            );
        } else {
            tempvar child_evm = child_evm;
        }

        return child_evm;
    }
}

namespace CallHelper {
    // @notice The shared logic of the CALL, CALLCODE, STATICCALL, and DELEGATECALL ops.
    // Loads the calldata from memory, constructs the child evm corresponding to the new
    //  execution frame of the call and returns it.
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
        value: Uint256*,
        caller: felt,
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

        tempvar authorized = new model.Option(is_some=0, value=0);
        tempvar message = new model.Message(
            bytecode=code,
            bytecode_len=code_len,
            valid_jumpdests_start=valid_jumpdests_start,
            valid_jumpdests=valid_jumpdests,
            calldata=calldata,
            calldata_len=args_size.low,
            value=value,
            caller=caller,
            parent=parent,
            address=to_address,
            code_address=code_address,
            read_only=read_only,
            is_create=FALSE,
            authorized=authorized,
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
        let is_reverted = is_not_zero(evm.reverted);
        Stack.push_uint128(1 - is_reverted);

        // Restore parent state if the call has reverted
        if (evm.reverted != FALSE) {
            tempvar state = evm.message.parent.state;
        } else {
            tempvar state = state;
        }
        let state = cast([ap - 1], model.State*);

        if (evm.reverted == Errors.EXCEPTIONAL_HALT) {
            // If the call has halted exceptionnaly, the return_data is empty
            // and nothing is copied to memory, and the gas is not returned;
            tempvar evm = new model.EVM(
                message=evm.message.parent.evm.message,
                return_data_len=0,
                return_data=evm.return_data,
                program_counter=evm.message.parent.evm.program_counter + 1,
                stopped=evm.message.parent.evm.stopped,
                gas_left=evm.message.parent.evm.gas_left,
                gas_refund=evm.message.parent.evm.gas_refund,
                reverted=evm.message.parent.evm.reverted,
            );
            return evm;
        }

        let actual_output_size_is_ret_size = is_le(ret_size.low, evm.return_data_len);
        let actual_output_size = actual_output_size_is_ret_size * ret_size.low + (
            1 - actual_output_size_is_ret_size
        ) * evm.return_data_len;
        Memory.store_n(actual_output_size, evm.return_data, ret_offset.low);

        tempvar evm = new model.EVM(
            message=evm.message.parent.evm.message,
            return_data_len=evm.return_data_len,
            return_data=evm.return_data,
            program_counter=evm.message.parent.evm.program_counter + 1,
            stopped=evm.message.parent.evm.stopped,
            gas_left=evm.message.parent.evm.gas_left + evm.gas_left,
            gas_refund=evm.message.parent.evm.gas_refund + evm.gas_refund,
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
        // (0xc0 + bytes_length) + (0x80 + 20) + address + nonce
        // or
        // (0xc0 + bytes_length) + (0x80 + 20) + address + (0x80 + nonce_len) + nonce
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
        let (message_bytes8_len, last_word, last_word_num_bytes) = bytes_to_bytes8_little_endian(
            message_bytes8, message_len, message
        );

        let (implementation) = Kakarot_cairo1_helpers_class_hash.read();
        let (msg_hash) = ICairo1Helpers.library_call_keccak(
            class_hash=implementation,
            words_len=message_bytes8_len,
            words=message_bytes8,
            last_input_word=last_word,
            last_input_num_bytes=last_word_num_bytes,
        );

        let address = uint256_to_uint160(msg_hash);
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
    }(sender_address: felt, bytecode_len: felt, bytecode: felt*, salt: Uint256) -> felt {
        alloc_locals;

        let (local bytecode_bytes8: felt*) = alloc();
        let (bytecode_bytes8_len, last_word, last_word_num_bytes) = bytes_to_bytes8_little_endian(
            bytecode_bytes8, bytecode_len, bytecode
        );

        let (implementation) = Kakarot_cairo1_helpers_class_hash.read();
        let (bytecode_hash) = ICairo1Helpers.library_call_keccak(
            class_hash=implementation,
            words_len=bytecode_bytes8_len,
            words=bytecode_bytes8,
            last_input_word=last_word,
            last_input_num_bytes=last_word_num_bytes,
        );

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
        let (packed_bytes8_len, last_word, last_word_num_bytes) = bytes_to_bytes8_little_endian(
            packed_bytes8, packed_bytes_len, packed_bytes
        );

        let (create2_hash) = ICairo1Helpers.library_call_keccak(
            class_hash=implementation,
            words_len=packed_bytes8_len,
            words=packed_bytes8,
            last_input_word=last_word,
            last_input_num_bytes=last_word_num_bytes,
        );
        let create2_address = uint256_to_uint160(create2_hash);

        return create2_address;
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
            let evm_contract_address = CreateHelper.get_create2_address(
                sender_address=evm_address, bytecode_len=bytecode_len, bytecode=bytecode, salt=salt
            );
            return evm_contract_address;
        }
    }

    // @notice At the end of a sub-context initiated with CREATE or CREATE2, the calling context's stack is updated.
    // @dev Restores the parent state if the sub-context has reverted.
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

        // Reverted during execution - either REVERT or exceptional
        if (evm.reverted != FALSE) {
            let is_exceptional_revert = is_not_zero(Errors.REVERT - evm.reverted);
            let return_data_len = (1 - is_exceptional_revert) * evm.return_data_len;
            let gas_left = evm.message.parent.evm.gas_left + (1 - is_exceptional_revert) *
                evm.gas_left;
            let gas_refund = evm.message.parent.evm.gas_refund + (1 - is_exceptional_revert) *
                evm.gas_refund;

            tempvar stack_code = new Uint256(low=0, high=0);
            Stack.push(stack_code);

            tempvar state = evm.message.parent.state;

            tempvar evm = new model.EVM(
                message=evm.message.parent.evm.message,
                return_data_len=return_data_len,
                return_data=evm.return_data,
                program_counter=evm.message.parent.evm.program_counter + 1,
                stopped=evm.message.parent.evm.stopped,
                gas_left=gas_left,
                gas_refund=gas_refund,
                reverted=evm.message.parent.evm.reverted,
            );
            return evm;
        }

        // Charge final deposit gas
        let code_size_limit = is_le(evm.return_data_len, Constants.MAX_CODE_SIZE);
        let code_deposit_cost = Gas.CODE_DEPOSIT * evm.return_data_len;
        let remaining_gas = evm.gas_left - code_deposit_cost;
        let enough_gas = is_nn(remaining_gas);
        // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-3540.md
        if (evm.return_data_len == 0) {
            tempvar is_prefix_not_0xef = TRUE;
        } else {
            tempvar is_prefix_not_0xef = is_not_zero(0xef - [evm.return_data]);
        }

        let success = enough_gas * code_size_limit * is_prefix_not_0xef;

        // Stack output: the address of the deployed contract, 0 if the deployment failed.
        let (address_high, address_low) = split_felt(evm.message.address.evm * success);
        tempvar address = new Uint256(low=address_low, high=address_high);
        Stack.push(address);

        if (success == FALSE) {
            tempvar state = evm.message.parent.state;

            tempvar evm = new model.EVM(
                message=evm.message.parent.evm.message,
                return_data_len=0,
                return_data=evm.return_data,
                program_counter=evm.message.parent.evm.program_counter + 1,
                stopped=evm.message.parent.evm.stopped,
                gas_left=evm.message.parent.evm.gas_left,
                gas_refund=evm.message.parent.evm.gas_refund,
                reverted=evm.message.parent.evm.reverted,
            );
            return evm;
        }

        // Write bytecode to Account
        let account = State.get_account(evm.message.address.evm);
        let account = Account.set_code(account, evm.return_data_len, evm.return_data);
        let account = Account.set_created(account, TRUE);
        State.update_account(account);

        tempvar evm = new model.EVM(
            message=evm.message.parent.evm.message,
            return_data_len=0,
            return_data=evm.return_data,
            program_counter=evm.message.parent.evm.program_counter + 1,
            stopped=evm.message.parent.evm.stopped,
            gas_left=evm.message.parent.evm.gas_left + remaining_gas,
            gas_refund=evm.message.parent.evm.gas_refund + evm.gas_refund,
            reverted=evm.message.parent.evm.reverted,
        );

        return evm;
    }
}
