// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_nn
from starkware.cairo.common.uint256 import Uint256, uint256_lt
from starkware.cairo.common.registers import get_fp_and_pc

// Internal dependencies
from kakarot.account import Account
from kakarot.storages import contract_account_class_hash, native_token_address
from kakarot.constants import Constants
from kakarot.errors import Errors
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.precompiles.precompiles import Precompiles
from kakarot.stack import Stack
from kakarot.state import State
from utils.rlp import RLP
from utils.utils import Helpers
from utils.uint256 import uint256_to_uint160

// @title System operations opcodes.
// @notice This file contains the functions to execute for system operations opcodes.
namespace SystemOperations {
    // @notice CREATE operation.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 3
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_create{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.call_context.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let (stack, popped) = Stack.pop_n(self=ctx.stack, n=3);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let sub_ctx = CreateHelper.initialize_sub_context(ctx=ctx, popped_len=3, popped=popped);

        return sub_ctx;
    }

    // @notice CREATE2 operation.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 4
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_create2{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.call_context.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let (stack, popped) = Stack.pop_n(self=ctx.stack, n=4);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let sub_ctx = CreateHelper.initialize_sub_context(ctx=ctx, popped_len=4, popped=popped);

        return sub_ctx;
    }

    // @notice INVALID operation.
    // @dev Equivalent to REVERT (since Byzantium fork) with 0,0 as stack parameters,
    //      except that all the gas given to the current context is consumed.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_invalid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // TODO: map the concept of consuming all the gas given to the context
        alloc_locals;
        let (revert_reason: felt*) = alloc();
        let ctx = ExecutionContext.stop(ctx, 0, revert_reason, TRUE);
        return ctx;
    }

    // @notice RETURN operation.
    // @dev Halt execution returning output data
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_return{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, popped) = Stack.pop_n(ctx.stack, 2);
        let offset = popped[0];
        let size = popped[1];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (offset.high + size.high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + size.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }

        let (local return_data: felt*) = alloc();
        let memory = Memory.load_n(ctx.memory, size.low, return_data, offset.low);

        let ctx = ExecutionContext.update_memory(ctx, memory);
        let ctx = ExecutionContext.stop(ctx, size.low, return_data, FALSE);

        return ctx;
    }

    // @notice REVERT operation.
    // @dev
    // @custom:since Byzantium
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_revert{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, popped) = Stack.pop_n(ctx.stack, 2);
        let offset = popped[0];
        let size = popped[1];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (offset.high + size.high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + size.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }

        // Load revert reason from offset
        let (return_data: felt*) = alloc();
        let memory = Memory.load_n(ctx.memory, size.low, return_data, offset.low);

        let ctx = ExecutionContext.update_memory(ctx, memory);
        let ctx = ExecutionContext.stop(ctx, size.low, return_data, TRUE);
        return ctx;
    }

    // @notice CALL operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 7
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // See https://docs.cairo-lang.org/0.12.0/how_cairo_works/functions.html#retrieving-registers
        alloc_locals;
        let fp_and_pc = get_fp_and_pc();
        local __fp__: felt* = fp_and_pc.fp_val;
        let sub_ctx = CallHelper.init_sub_context(
            ctx=ctx, with_value=TRUE, read_only=ctx.call_context.read_only, self_call=FALSE
        );
        if (sub_ctx.reverted != 0) {
            return sub_ctx;
        }

        if (ctx.call_context.read_only * sub_ctx.call_context.value != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let ctx = sub_ctx.call_context.calling_context;
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let (value_high, value_low) = split_felt(sub_ctx.call_context.value);
        tempvar value = Uint256(value_low, value_high);

        let calling_context = sub_ctx.call_context.calling_context;
        let transfer = model.Transfer(
            calling_context.call_context.address, sub_ctx.call_context.address, value
        );
        let (state, success) = State.add_transfer(sub_ctx.state, transfer);
        let sub_ctx = ExecutionContext.update_state(sub_ctx, state);
        if (success == 0) {
            let (revert_reason_len, revert_reason) = Errors.balanceError();
            tempvar sub_ctx = ExecutionContext.stop(
                sub_ctx, revert_reason_len, revert_reason, TRUE
            );
        } else {
            tempvar sub_ctx = sub_ctx;
        }

        return sub_ctx;
    }

    // @notice STATICCALL operation.
    // @dev
    // @custom:since Homestead
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 6
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_staticcall{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let sub_ctx = CallHelper.init_sub_context(
            ctx=ctx, with_value=FALSE, read_only=TRUE, self_call=FALSE
        );
        return sub_ctx;
    }

    // @notice CALLCODE operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 7
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_callcode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let sub_ctx = CallHelper.init_sub_context(
            ctx=ctx, with_value=TRUE, read_only=ctx.call_context.read_only, self_call=TRUE
        );

        return sub_ctx;
    }

    // @notice DELEGATECALL operation.
    // @dev
    // @custom:since Byzantium
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 6
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_delegatecall{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let sub_ctx = CallHelper.init_sub_context(
            ctx=ctx, with_value=FALSE, read_only=ctx.call_context.read_only, self_call=TRUE
        );

        return sub_ctx;
    }

    // @notice SELFDESTRUCT operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 3000 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @return ExecutionContext The pointer to the updated execution_context.
    func exec_selfdestruct{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.call_context.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // Transfer funds
        let (stack, popped) = Stack.pop(ctx.stack);
        let recipient_evm_address = uint256_to_uint160([popped]);

        // Remove this when https://eips.ethereum.org/EIPS/eip-6780 is validated
        if (recipient_evm_address == ctx.call_context.address.evm) {
            tempvar is_recipient_self = TRUE;
        } else {
            tempvar is_recipient_self = FALSE;
        }
        let recipient_evm_address = (1 - is_recipient_self) * recipient_evm_address;

        let (recipient_starknet_address) = Account.compute_starknet_address(recipient_evm_address);
        tempvar recipient = new model.Address(recipient_starknet_address, recipient_evm_address);
        let (state, account) = State.get_account(ctx.state, ctx.call_context.address);
        let transfer = model.Transfer(
            sender=ctx.call_context.address, recipient=recipient, amount=[account.balance]
        );
        let (state, success) = State.add_transfer(state, transfer);

        // Register for SELFDESTRUCT
        let (state, account) = State.get_account(state, ctx.call_context.address);
        let account = Account.selfdestruct(account);
        let state = State.set_account(state, ctx.call_context.address, account);

        // Halt context
        let (return_data: felt*) = alloc();
        let ctx = ExecutionContext.stop(ctx, 0, return_data, FALSE);

        let ctx = ExecutionContext.update_state(ctx, state);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        return ctx;
    }
}

namespace CallHelper {
    // @notice The shared logic of the CALL ops, allowing CALL, CALLCODE, STATICCALL, and DELEGATECALL to
    //         share structure and parameterize whether the call requires a value (CALL, CALLCODE) and
    //         whether the returned sub context's is read only (STATICCODE)
    // @param calling_ctx The pointer to the calling execution context.
    // @param with_value The boolean that determines whether the sub-context's calling context has a value read
    //        from the calling context's stack or the calling context's calling context.
    // @param read_only The boolean that determines whether state modifications can be executed from the sub-execution context.
    // @param self_call A boolean to indicate whether the account to message-call into is self (address of the current executing account)
    //        or the call argument's address (address of the call's target account)
    // @return ExecutionContext The pointer to the sub context.
    func init_sub_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        ctx: model.ExecutionContext*, with_value: felt, read_only: felt, self_call: felt
    ) -> model.ExecutionContext* {
        alloc_locals;

        // 1. Parse args from Stack
        // Note: We don't pop ret_offset and ret_size here but at the end of the sub context
        // See finalize_calling_context
        // Pop ret_offset and ret_size
        let (stack, popped) = Stack.pop_n(ctx.stack, 4 + with_value);
        let (stack, ret_offset) = Stack.peek(stack, 0);
        let (stack, ret_size) = Stack.peek(stack, 1);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (ret_offset.high + ret_size.high + popped[2 + with_value].high + popped[3 + with_value].high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        let gas = popped[0];
        let address = uint256_to_uint160(popped[1]);
        // TODO: handle value as uint256, need to refacto the exec_calls
        let value = with_value * popped[2].low + (1 - with_value) * ctx.call_context.value;
        let args_offset = popped[2 + with_value].low;
        let args_size = popped[3 + with_value].low;

        // 2. Gas
        // Memory expansion cost
        let max_expansion_is_ret = is_le(args_offset + args_size, ret_offset.low + ret_size.low);
        let max_expansion = max_expansion_is_ret * (ret_offset.low + ret_size.low) + (
            1 - max_expansion_is_ret
        ) * (args_offset + args_size);
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, max_expansion);

        // TODO
        // Transfer gas cost
        // Access list

        // Max between given gas arg and max allowed gas := available_gas - (available_gas // 64)
        let available_gas = ctx.call_context.gas_limit - ctx.gas_used;
        let (max_message_call_gas, _) = unsigned_div_rem(available_gas, 64);
        tempvar max_message_call_gas = available_gas - max_message_call_gas;
        let (max_message_call_gas_high, max_message_call_gas_low) = split_felt(
            max_message_call_gas
        );
        let (max_gas_is_message_call_gas) = uint256_lt(
            Uint256(max_message_call_gas_low, max_message_call_gas_high), gas
        );
        local gas_limit;
        if (max_gas_is_message_call_gas == FALSE) {
            // If gas is lower, it means that it fits in a felt and this is safe
            assert gas_limit = gas.low + gas.high * 2 ** 128;
        } else {
            assert gas_limit = max_message_call_gas;
        }
        // All the gas is charged upfront and remaining gis is refunded at the end
        let ctx = ExecutionContext.charge_gas(ctx, gas_limit + memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }

        // 3. Calldata
        let (calldata: felt*) = alloc();
        let memory = Memory.load_n(ctx.memory, args_size, calldata, args_offset);
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // 4. Build sub_ctx
        // Check if the called address is a precompiled contract
        let is_precompile = Precompiles.is_precompile(address=address);
        if (is_precompile != FALSE) {
            let sub_ctx = Precompiles.run(
                evm_address=address,
                calldata_len=args_size,
                calldata=calldata,
                value=value,
                calling_context=ctx,
            );

            return sub_ctx;
        }

        let (starknet_contract_address) = Account.compute_starknet_address(address);
        tempvar call_address = new model.Address(starknet_contract_address, address);
        let (state, account) = State.get_account(ctx.state, call_address);
        let ctx = ExecutionContext.update_state(ctx, state);

        if (self_call == FALSE) {
            tempvar call_context_address = call_address;
        } else {
            tempvar call_context_address = ctx.call_context.address;
        }

        tempvar call_context = new model.CallContext(
            bytecode=account.code,
            bytecode_len=account.code_len,
            calldata=calldata,
            calldata_len=args_size,
            value=value,
            gas_limit=gas_limit,
            gas_price=ctx.call_context.gas_price,
            origin=ctx.call_context.origin,
            calling_context=ctx,
            address=call_context_address,
            read_only=read_only,
            is_create=FALSE,
        );
        let sub_ctx = ExecutionContext.init(call_context, 0);
        let state = State.copy(ctx.state);
        let sub_ctx = ExecutionContext.update_state(sub_ctx, state);
        return sub_ctx;
    }

    // @notice At the end of a sub-context call, the calling context's stack and memory are updated.
    // @return ExecutionContext The pointer to the updated calling context.
    func finalize_calling_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(summary: ExecutionContext.Summary*) -> model.ExecutionContext* {
        alloc_locals;

        // Pop ret_offset and ret_size
        // See init_sub_context, the Stack here is guaranteed to have enough items
        let (stack, popped) = Stack.pop_n(self=summary.calling_context.stack, n=2);
        let ret_offset = popped[0].low;
        let ret_size = popped[1].low;

        // Put status in stack
        let stack = Stack.push_uint128(stack, 1 - summary.reverted);

        // Store RETURN_DATA in memory
        let return_data = Helpers.slice_data(
            data_len=summary.return_data_len,
            data=summary.return_data,
            data_offset=0,
            slice_len=ret_size,
        );
        let memory = Memory.store_n(
            summary.calling_context.memory, ret_size, return_data, ret_offset
        );

        // Gas not used is returned when ctx is not reverted
        let remaining_gas = (summary.call_context.gas_limit - summary.gas_used) * (
            1 - summary.reverted
        );
        tempvar ctx = new model.ExecutionContext(
            state=summary.calling_context.state,
            call_context=summary.calling_context.call_context,
            stack=stack,
            memory=memory,
            return_data_len=summary.return_data_len,
            return_data=summary.return_data,
            program_counter=summary.calling_context.program_counter,
            stopped=summary.calling_context.stopped,
            gas_used=summary.calling_context.gas_used - remaining_gas,
            reverted=summary.calling_context.reverted,
        );

        // REVERTED, just update Stack and Memory
        if (summary.reverted != FALSE) {
            return ctx;
        }

        let ctx = ExecutionContext.update_state(ctx, summary.state);

        return ctx;
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
    // @return ExecutionContext The pointer to the updated calling context.
    func get_create_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(sender_address: felt, nonce: felt) -> (evm_contract_address: felt) {
        alloc_locals;
        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        let (local address_packed_bytes: felt*) = alloc();

        // pack sender address, padded twenty bytes
        // the address should be twenty bytes, so we skip the leading 12 elements
        let (sender_address_high, sender_address_low) = split_felt(sender_address);

        let (address_packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
            value=Uint256(low=sender_address_low, high=sender_address_high),
            byte_array_offset=12,
            byte_array_len=Constants.ADDRESS_BYTES_LEN,
            dest_offset=0,
            dest_len=0,
            dest=address_packed_bytes,
        );

        // encode address rlp
        let (local packed_bytes: felt*) = alloc();
        let (packed_bytes_len) = RLP.encode_byte_array(
            address_packed_bytes_len, address_packed_bytes, 0, packed_bytes
        );

        // encode nonce rlp
        let (packed_bytes_len) = RLP.encode_felt(nonce, packed_bytes_len, packed_bytes);

        let (local rlp_list: felt*) = alloc();
        let (rlp_list_len: felt) = RLP.encode_list(packed_bytes_len, packed_bytes, rlp_list);

        let (local packed_bytes8: felt*) = alloc();
        Helpers.bytes_to_bytes8_little_endian(
            bytes_len=rlp_list_len,
            bytes=rlp_list,
            index=0,
            size=rlp_list_len,
            bytes8=0,
            bytes8_shift=0,
            dest=packed_bytes8,
            dest_index=0,
        );

        with keccak_ptr {
            let (create_hash) = cairo_keccak_bigend(inputs=packed_bytes8, n_bytes=rlp_list_len);

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }

        let create_address = Helpers.keccak_hash_to_evm_contract_address(create_hash);
        return (create_address,);
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
    // @return ExecutionContext The pointer to the updated calling context.
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
        Helpers.bytes_to_bytes8_little_endian(
            bytes_len=bytecode_len,
            bytes=bytecode,
            index=0,
            size=bytecode_len,
            bytes8=0,
            bytes8_shift=0,
            dest=bytecode_bytes8,
            dest_index=0,
        );
        with keccak_ptr {
            // get keccak hash of bytecode
            let (bytecode_hash_bigend) = cairo_keccak_bigend(
                inputs=bytecode_bytes8, n_bytes=bytecode_len
            );
            // get keccak hash of
            // marker + caller_address + salt + bytecode_hash
            let (local packed_bytes: felt*) = alloc();

            // 0xff is by convention the marker involved in deterministic address creation for create2
            let (packed_bytes_len) = Helpers.felt_to_bytes(0xff, 0, packed_bytes);

            // pack sender address, padded twenty bytes
            // the address should be twenty bytes, so we skip the leading 12 elements
            let (sender_address_high, sender_address_low) = split_felt(sender_address);
            let (packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
                value=Uint256(low=sender_address_low, high=sender_address_high),
                byte_array_offset=12,
                byte_array_len=Constants.ADDRESS_BYTES_LEN,
                dest_offset=packed_bytes_len,
                dest_len=packed_bytes_len,
                dest=packed_bytes,
            );

            // pack salt, padded 32 bytes
            let (packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
                value=salt,
                byte_array_offset=0,
                byte_array_len=32,
                dest_offset=packed_bytes_len,
                dest_len=packed_bytes_len,
                dest=packed_bytes,
            );

            // pack bytecode keccak hash, padded 32 bytes
            let (packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
                value=bytecode_hash_bigend,
                byte_array_offset=0,
                byte_array_len=32,
                dest_offset=packed_bytes_len,
                dest_len=packed_bytes_len,
                dest=packed_bytes,
            );

            let (local packed_bytes8: felt*) = alloc();
            Helpers.bytes_to_bytes8_little_endian(
                bytes_len=packed_bytes_len,
                bytes=packed_bytes,
                index=0,
                size=packed_bytes_len,
                bytes8=0,
                bytes8_shift=0,
                dest=packed_bytes8,
                dest_index=0,
            );

            let (create2_hash) = cairo_keccak_bigend(
                inputs=packed_bytes8, n_bytes=packed_bytes_len
            );

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }

        let create2_address = Helpers.keccak_hash_to_evm_contract_address(create2_hash);
        return (create2_address,);
    }

    // @notice Pre-compute the evm address of a contract account before deploying it.
    func get_evm_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        state: model.State*,
        address: model.Address*,
        popped_len: felt,
        popped: Uint256*,
        bytecode_len: felt,
        bytecode: felt*,
    ) -> (model.State*, felt) {
        alloc_locals;
        let (state, account) = State.get_account(state, address);
        let nonce = account.nonce;

        // create2 context pops 4 off the stack, create pops 3
        // so we use popped_len to derive the way we should handle
        // the creation of evm addresses
        if (popped_len != 4) {
            let (evm_contract_address) = CreateHelper.get_create_address(address.evm, nonce);
            return (state, evm_contract_address);
        } else {
            let salt = popped[3];
            let (evm_contract_address) = CreateHelper.get_create2_address(
                sender_address=address.evm, bytecode_len=bytecode_len, bytecode=bytecode, salt=salt
            );
            return (state, evm_contract_address);
        }
    }

    // @notice Deploy a new Contract account and initialize a sub context at these addresses
    //         with bytecode from calling context memory.
    // @param ctx The pointer to the calling context.
    // @param popped_len The length of popped.
    // @param popped The memory.
    // @return ExecutionContext The pointer to the updated calling context.
    func initialize_sub_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*, popped_len: felt, popped: Uint256*) -> model.ExecutionContext* {
        alloc_locals;

        let value = popped[0];
        let offset = popped[1];
        let size = popped[2];

        // Gas
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + size.low);
        let (init_code_gas, _) = unsigned_div_rem(size.low + 31, 31);
        let init_code_gas = 2 * init_code_gas;
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost + init_code_gas);
        if (ctx.reverted != FALSE) {
            return ctx;
        }

        let (bytecode: felt*) = alloc();
        let memory = Memory.load_n(ctx.memory, size.low, bytecode, offset.low);
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Get target account
        let (state, evm_contract_address) = get_evm_address(
            ctx.state, ctx.call_context.address, popped_len, popped, size.low, bytecode
        );
        let (starknet_contract_address) = Account.compute_starknet_address(evm_contract_address);
        tempvar address = new model.Address(starknet_contract_address, evm_contract_address);

        let (state, sender) = State.get_account(state, ctx.call_context.address);
        let ctx = ExecutionContext.update_state(ctx, state);
        let balance = [sender.balance];
        let (insufficient_balance) = uint256_lt(balance, value);
        if (insufficient_balance != 0) {
            let stack = Stack.push_uint128(ctx.stack, 0);
            let ctx = ExecutionContext.update_stack(ctx, stack);
            return ctx;
        }

        let available_gas = ctx.call_context.gas_limit - ctx.gas_used;
        let (gas_limit, _) = unsigned_div_rem(available_gas, 64);
        let gas_limit = available_gas - gas_limit;
        let ctx = ExecutionContext.charge_gas(ctx, gas_limit);

        let sender = Account.set_nonce(sender, sender.nonce + 1);
        let state = State.set_account(state, ctx.call_context.address, sender);
        let ctx = ExecutionContext.update_state(ctx, state);

        let (state, account) = State.get_account(state, address);
        let is_collision = Account.has_code_or_nonce(account);
        if (is_collision != 0) {
            let stack = Stack.push_uint128(ctx.stack, 0);
            let ctx = ExecutionContext.update_stack(ctx, stack);
            let ctx = ExecutionContext.update_state(ctx, state);
            return ctx;
        }
        let account = Account.set_nonce(account, 1);
        let state = State.set_account(state, address, account);
        let ctx = ExecutionContext.update_state(ctx, state);

        // Create sub context with copied state
        let state = State.copy(ctx.state);
        let (state, account) = State.get_account(state, address);
        let state = State.set_account(state, address, account);
        let (calldata: felt*) = alloc();
        tempvar call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=size.low,
            calldata=calldata,
            calldata_len=0,
            value=value.low,
            gas_limit=gas_limit,
            gas_price=ctx.call_context.gas_price,
            origin=ctx.call_context.origin,
            calling_context=ctx,
            address=address,
            read_only=FALSE,
            is_create=TRUE,
        );
        let sub_ctx = ExecutionContext.init(call_context, 0);

        let transfer = model.Transfer(
            sender=ctx.call_context.address, recipient=address, amount=value
        );
        let (state, success) = State.add_transfer(state, transfer);

        if (success == 0) {
            let (revert_reason_len, revert_reason) = Errors.balanceError();
            let sub_ctx = ExecutionContext.stop(sub_ctx, revert_reason_len, revert_reason, TRUE);
            let sub_ctx = ExecutionContext.update_state(sub_ctx, state);
            return sub_ctx;
        }
        let sub_ctx = ExecutionContext.update_state(sub_ctx, state);

        return sub_ctx;
    }

    // @notice At the end of a sub-context initiated with CREATE or CREATE2, the calling context's stack is updated.
    // @param ctx The pointer to the calling context.
    // @return ExecutionContext The pointer to the updated calling context.
    func finalize_calling_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(summary: ExecutionContext.Summary*) -> model.ExecutionContext* {
        alloc_locals;

        // Charge final deposit gas
        let code_size_limit = is_le(summary.return_data_len, 0x6000);
        let code_deposit_cost = 200 * summary.return_data_len;
        let remaining_gas = summary.call_context.gas_limit - summary.gas_used - code_deposit_cost;
        let enough_gas = is_nn(remaining_gas);
        let success = (1 - summary.reverted) * enough_gas * code_size_limit;

        // Stack output: the address of the deployed contract, 0 if the deployment failed.
        let (address_high, address_low) = split_felt(summary.address.evm * success);
        tempvar address = new Uint256(low=address_low, high=address_high);
        let stack = Stack.push(summary.calling_context.stack, address);

        // Re-create the calling context with updated stack and return_data
        // Gas not used is returned when ctx is not reverted
        // In the case of a reverted create context, the gas of the reverted context should be rolled back and not consumed
        tempvar ctx = new model.ExecutionContext(
            state=summary.calling_context.state,
            call_context=summary.calling_context.call_context,
            stack=stack,
            memory=summary.calling_context.memory,
            return_data_len=summary.return_data_len,
            return_data=summary.return_data,
            program_counter=summary.calling_context.program_counter,
            stopped=summary.calling_context.stopped,
            gas_used=summary.calling_context.gas_used - remaining_gas * success,
            reverted=1 - success,
        );

        // REVERTED, just returns
        if (success == FALSE) {
            return ctx;
        }

        // Write bytecode to Account
        let (state, account) = State.get_account(summary.state, summary.address);
        let account = Account.set_code(account, summary.return_data_len, summary.return_data);
        let state = State.set_account(state, summary.address, account);

        let ctx = ExecutionContext.update_state(ctx, state);

        return ctx;
    }
}
