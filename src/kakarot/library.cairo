// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy
from starkware.cairo.common.uint256 import Uint256

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// Internal dependencies
from kakarot.model import model
from kakarot.instructions import EVMInstructions
from kakarot.interfaces.interfaces import IRegistry
from kakarot.execution_context import ExecutionContext
from kakarot.constants import native_token_address, registry_address, evm_contract_class_hash
from utils.utils import Helpers

@storage_var
func salt() -> (value: felt) {
}

// An event emitted whenever kakarot deploys a evm contract
// evm_contract_address is the representation of the evm address of the contract
// starknet_contract_address if the starknet address of the contract
@event
func evm_contract_deployed(evm_contract_address: felt, starknet_contract_address: felt) {
}

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
// @author @abdelhamidbakhta
// @custom:namespace Kakarot
namespace Kakarot {
    // @notice The constructor of the contract.
    // @param _owner The address of the owner of the contract.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(owner: felt, native_token_address_, class_hash: felt) {
        Ownable.initializer(owner);
        evm_contract_class_hash.write(class_hash);
        native_token_address.write(native_token_address_);
        return ();
    }

    // @notice Execute an EVM bytecode.
    // @param _bytecode The bytecode to execute.
    // @param calldata The calldata to pass to the bytecode.
    // @return The pointer to the execution context.
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(code: felt*, code_len: felt, calldata: felt*) -> model.ExecutionContext* {
        alloc_locals;

        // Load helper hints
        Helpers.setup_python_defs();

        // Generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(ctx);

        // Start execution
        let ctx = run(instructions, ctx);

        // For debugging purpose
        ExecutionContext.dump(ctx);

        return ctx;
    }

    // @notice Execute an EVM bytecode.
    // @param _bytecode The bytecode to execute.
    // @param calldata The calldata to pass to the bytecode.
    // @return The pointer to the execution context.
    func execute_at_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(address: felt, calldata_len: felt, calldata: felt*) -> model.ExecutionContext* {
        alloc_locals;

        // Load helper hints
        Helpers.setup_python_defs();

        // Generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init_evm(
            address, calldata_len, calldata
        );

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(ctx);

        // Start execution
        let ctx = run(instructions, ctx);

        // For debugging purpose
        ExecutionContext.dump(ctx);

        return ctx;
    }

    // @notice Run the execution of the bytecode.
    // @param instructions The instructions set.
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(instructions: felt*, ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Decode and execute
        let ctx: model.ExecutionContext* = EVMInstructions.decode_and_execute(instructions, ctx);

        // Check if execution should be stopped
        let stopped: felt = ExecutionContext.is_stopped(ctx);

        // Terminate execution
        if (stopped == TRUE) {
            return ctx;
        }

        // Continue execution
        return run(instructions, ctx);
    }

    // @notice Sets the account registry address.
    // @param account registry address.
    // @return None.
    func set_account_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        registry_address_: felt
    ) {
        Ownable.assert_only_owner();
        registry_address.write(registry_address_);
        return ();
    }

    // @notice Sets the native token address.
    // @param native token address.
    // @return None.
    func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        native_token_address_: felt
    ) {
        Ownable.assert_only_owner();
        native_token_address.write(native_token_address_);
        return ();
    }

    // @notice Deploy the starknetcontract holding the evm code
    // @param bytes: byte code stored in the new contract
    // @return evm_contract_address: address that is mapped to the actual new contract address
    @external
    func deploy_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytes_len: felt, bytes: felt*
    ) -> (evm_contract_address: felt, starknet_contract_address: felt) {
        alloc_locals;
        let (current_salt) = salt.read();
        let (class_hash) = evm_contract_class_hash.read();

        let (local calldata: felt*) = alloc();
        let (kakarot_address) = Ownable.owner();

        assert [calldata] = kakarot_address;
        assert [calldata + 1] = bytes_len;
        memcpy(dst=calldata + 2, src=bytes, len=bytes_len);

        let (contract_address) = deploy(
            class_hash=class_hash,
            contract_address_salt=current_salt,
            constructor_calldata_size=bytes_len + 2,
            constructor_calldata=calldata,
            deploy_from_zero=FALSE,
        );
        salt.write(value=current_salt + 1);
        // Generate EVM_contract address from the new cairo contract
        // let (evm_contract_address,_) = unsigned_div_rem(contract_address, 1000000000000000000000000000000000000000000000000);
        let evm_contract_address = 123 + current_salt;

        // Save address of new contracts
        let (reg_address) = registry_address.read();
        IRegistry.set_account_entry(reg_address, contract_address, evm_contract_address);
        return (
            evm_contract_address=evm_contract_address, starknet_contract_address=contract_address
        );
    }
}
