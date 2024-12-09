use core::num::traits::CheckedAdd;
use crate::call_helpers::CallHelpers;
use crate::create_helpers::{CreateHelpers, CreateType};
use crate::errors::{ensure, EVMError};
use crate::gas;
use crate::memory::MemoryTrait;
use crate::model::Transfer;
use crate::model::account::{AccountTrait};
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;
use crate::state::StateTrait;
use utils::set::SetTrait;

#[generate_trait]
pub impl SystemOperations of SystemOperationsTrait {
    /// CREATE
    /// # Specification: https://www.evm.codes/#f0?fork=shanghai
    fn exec_create(ref self: VM) -> Result<(), EVMError> {
        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

        let create_args = self.prepare_create(CreateType::Create)?;
        self.generic_create(create_args)
    }


    /// CALL
    /// # Specification: https://www.evm.codes/#f1?fork=shanghai
    fn exec_call(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_saturating_u64()?;
        let to = self.stack.pop_eth_address()?;
        let value = self.stack.pop()?;
        let args_offset = self.stack.pop_saturating_usize()?;
        let args_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.
        let ret_offset = self.stack.pop_saturating_usize()?;
        let ret_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        // GAS
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(args_offset, args_size), (ret_offset, ret_size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);

        let access_gas_cost = if self.accessed_addresses.contains(to) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(to);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let create_gas_cost = if self.env.state.is_account_alive(to) || value == 0 {
            0
        } else {
            gas::NEWACCOUNT
        };

        let transfer_gas_cost = if value != 0 {
            gas::CALLVALUE
        } else {
            0
        };

        let message_call_gas = gas::calculate_message_call_gas(
            value,
            gas,
            self.gas_left(),
            memory_expansion.expansion_cost,
            access_gas_cost + transfer_gas_cost + create_gas_cost
        )?;
        let total_cost = message_call_gas
            .cost
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;
        // Only the transfer gas is left to charge.

        let read_only = self.message().read_only;

        // Check if current context is read only that value == 0.
        // De Morgan's law: !(read_only && value != 0) == !read_only || value == 0
        ensure(!read_only || value == 0, EVMError::WriteInStaticContext)?;

        // If sender_balance < value, return early, pushing
        // 0 on the stack to indicate call failure.
        // The gas cost relative to the transfer is refunded.
        let sender_balance = self.env.state.get_account(self.message().target.evm).balance();
        if sender_balance < value {
            self.return_data = [].span();
            self.gas_left += message_call_gas.stipend;
            return self.stack.push(0);
        }

        self
            .generic_call(
                gas: message_call_gas.stipend,
                :value,
                caller: self.message().target.evm,
                :to,
                code_address: to,
                should_transfer_value: true,
                is_staticcall: false,
                :args_offset,
                :args_size,
                :ret_offset,
                :ret_size,
            )
    }


    /// CALLCODE
    /// # Specification: https://www.evm.codes/#f2?fork=shanghai
    fn exec_callcode(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_saturating_u64()?;
        let code_address = self.stack.pop_eth_address()?;
        let value = self.stack.pop()?;
        let args_offset = self.stack.pop_saturating_usize()?;
        let args_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.
        let ret_offset = self.stack.pop_saturating_usize()?;
        let ret_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        let to = self.message().target.evm;

        // GAS
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(args_offset, args_size), (ret_offset, ret_size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);

        let access_gas_cost = if self.accessed_addresses.contains(code_address) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(code_address);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let transfer_gas_cost = if value != 0 {
            gas::CALLVALUE
        } else {
            0
        };

        let message_call_gas = gas::calculate_message_call_gas(
            value,
            gas,
            self.gas_left(),
            memory_expansion.expansion_cost,
            access_gas_cost + transfer_gas_cost
        )?;
        self.charge_gas(message_call_gas.cost + memory_expansion.expansion_cost)?;

        // If sender_balance < value, return early, pushing
        // 0 on the stack to indicate call failure.
        // The gas cost relative to the transfer is refunded.
        let sender_balance = self.env.state.get_account(self.message().target.evm).balance();
        if sender_balance < value {
            self.return_data = [].span();
            self.gas_left += message_call_gas.stipend;
            return self.stack.push(0);
        }

        self
            .generic_call(
                message_call_gas.stipend,
                value,
                self.message().target.evm,
                to,
                code_address,
                true,
                false,
                args_offset,
                args_size,
                ret_offset,
                ret_size,
            )
    }
    /// RETURN
    /// # Specification: https://www.evm.codes/#f3?fork=shanghai
    fn exec_return(ref self: VM) -> Result<(), EVMError> {
        let offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?;
        let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, size)].span())?;
        self.memory.ensure_length(memory_expansion.new_size);
        self.charge_gas(gas::ZERO + memory_expansion.expansion_cost)?;

        let mut return_data = Default::default();
        self.memory.load_n(size, ref return_data, offset);

        // Set the memory data to the parent context return data
        // and halt the context.
        self.set_return_data(return_data.span());
        self.stop();
        Result::Ok(())
    }

    /// DELEGATECALL
    /// # Specification: https://www.evm.codes/#f4?fork=shanghai
    fn exec_delegatecall(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_saturating_u64()?;
        let code_address = self.stack.pop_eth_address()?;
        let args_offset = self.stack.pop_saturating_usize()?;
        let args_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.
        let ret_offset = self.stack.pop_saturating_usize()?;
        let ret_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        // GAS
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(args_offset, args_size), (ret_offset, ret_size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);

        let access_gas_cost = if self.accessed_addresses.contains(code_address) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(code_address);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let message_call_gas = gas::calculate_message_call_gas(
            0, gas, self.gas_left(), memory_expansion.expansion_cost, access_gas_cost
        )?;
        let total_cost = message_call_gas
            .cost
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;

        self
            .generic_call(
                message_call_gas.stipend,
                self.message().value,
                self.message().caller.evm,
                self.message().target.evm,
                code_address,
                false,
                false,
                args_offset,
                args_size,
                ret_offset,
                ret_size,
            )
    }

    /// CREATE2
    /// # Specification: https://www.evm.codes/#f5?fork=shanghai
    fn exec_create2(ref self: VM) -> Result<(), EVMError> {
        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

        let create_args = self.prepare_create(CreateType::Create2)?;
        self.generic_create(create_args)
    }

    /// STATICCALL
    /// # Specification: https://www.evm.codes/#fa?fork=shanghai
    fn exec_staticcall(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_saturating_u64()?;
        let to = self.stack.pop_eth_address()?;
        let args_offset = self.stack.pop_saturating_usize()?;
        let args_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.
        let ret_offset = self.stack.pop_saturating_usize()?;
        let ret_size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        // GAS
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(args_offset, args_size), (ret_offset, ret_size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);

        let access_gas_cost = if self.accessed_addresses.contains(to) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(to);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let message_call_gas = gas::calculate_message_call_gas(
            0, gas, self.gas_left(), memory_expansion.expansion_cost, access_gas_cost
        )?;
        let gas_to_charge = message_call_gas
            .cost
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(gas_to_charge)?;

        self
            .generic_call(
                message_call_gas.stipend,
                0,
                self.message().target.evm,
                to,
                to,
                true,
                true,
                args_offset,
                args_size,
                ret_offset,
                ret_size,
            )
    }


    /// REVERT
    /// # Specification: https://www.evm.codes/#fd?fork=shanghai
    fn exec_revert(ref self: VM) -> Result<(), EVMError> {
        let offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, size)].span())?;
        self.memory.ensure_length(memory_expansion.new_size);
        self.charge_gas(memory_expansion.expansion_cost)?;

        let mut return_data = Default::default();
        self.memory.load_n(size, ref return_data, offset);

        // Set the memory data to the parent context return data
        // and halt the context.
        self.set_return_data(return_data.span());
        self.stop();
        self.set_error();
        Result::Ok(())
    }

    /// INVALID
    /// # Specification: https://www.evm.codes/#fe?fork=shanghai
    fn exec_invalid(ref self: VM) -> Result<(), EVMError> {
        Result::Err(EVMError::InvalidOpcode(0xfe))
    }


    /// SELFDESTRUCT
    /// # Specification: https://www.evm.codes/#ff?fork=shanghai
    fn exec_selfdestruct(ref self: VM) -> Result<(), EVMError> {
        let recipient = self.stack.pop_eth_address()?;

        // GAS
        let mut gas_cost = gas::SELFDESTRUCT;
        if !self.accessed_addresses.contains(recipient) {
            self.accessed_addresses.add(recipient);
            gas_cost += gas::COLD_ACCOUNT_ACCESS_COST;
        };

        let mut self_account = self.env.state.get_account(self.message().target.evm);
        let self_balance = self_account.balance();
        if (!self.env.state.is_account_alive(recipient) && self_balance != 0) {
            gas_cost += gas::NEWACCOUNT;
        }
        self.charge_gas(gas_cost)?;

        // Operation
        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

        // If the account was created in the same transaction and recipient is self, the native
        // token is burnt
        let recipient_evm_address = if (self_account.is_created
            && recipient == self_account.evm_address()) {
            0.try_into().unwrap()
        } else {
            recipient
        };
        let recipient_account = self.env.state.get_account(recipient_evm_address);
        // Transfer balance
        self
            .env
            .state
            .add_transfer(
                Transfer {
                    sender: self_account.address(),
                    recipient: recipient_account.address(),
                    amount: self_balance
                }
            )?;

        //@dev: get_account again because add_transfer modified its balance
        self_account = self.env.state.get_account(self.message().target.evm);
        // Register for selfdestruct
        self_account.selfdestruct();
        self.env.state.set_account(self_account);
        self.stop();
        Result::Ok(())
    }
}

#[cfg(test)]
mod tests {
    use contracts::test_data::{storage_evm_bytecode, storage_evm_initcode};
    use core::result::ResultTrait;
    use core::starknet::EthAddress;
    use core::traits::TryInto;
    use crate::call_helpers::CallHelpersImpl;
    use crate::instructions::MemoryOperationTrait;
    use crate::instructions::SystemOperationsTrait;
    use crate::interpreter::{EVMTrait};
    use crate::model::account::{Account};
    use crate::model::vm::VMTrait;
    use crate::model::{AccountTrait, Address};
    use crate::stack::StackTrait;
    use crate::state::{StateTrait};
    use crate::test_utils::{
        VMBuilderTrait, MemoryTestUtilsTrait, native_token, evm_address, setup_test_environment,
        origin, uninitialized_account
    };
    use snforge_std::{test_address, start_mock_call};
    use utils::constants::EMPTY_KECCAK;
    use utils::helpers::compute_starknet_address;
    use utils::traits::bytes::{U8SpanExTrait, FromBytes};

    use utils::traits::{EthAddressIntoU256};


    #[test]
    fn test_exec_return() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // When
        vm.stack.push(1000).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.exec_mstore().expect('exec_mstore failed');

        vm.stack.push(32).expect('push failed');
        vm.stack.push(0).expect('push failed');
        assert(vm.exec_return().is_ok(), 'Exec return failed');

        let return_data = vm.return_data();
        let parsed_return_data: u256 = return_data
            .from_be_bytes()
            .expect('Failed to parse return data');
        assert(1000 == parsed_return_data, 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');
        assert_eq!(vm.error, false);
    }

    #[test]
    fn test_exec_revert() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // When
        vm.stack.push(1000).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.exec_mstore().expect('exec_mstore failed');

        vm.stack.push(32).expect('push failed');
        vm.stack.push(0).expect('push failed');
        assert(vm.exec_revert().is_ok(), 'Exec revert failed');

        let return_data = vm.return_data();
        let parsed_return_data: u256 = return_data
            .from_be_bytes()
            .expect('Failed to parse return data');
        assert(1000 == parsed_return_data, 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');
        assert_eq!(vm.error, true);
    }

    #[test]
    fn test_exec_return_with_offset() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // When
        vm.stack.push(1).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.exec_mstore().expect('exec_mstore failed');

        vm.stack.push(32).expect('push failed');
        vm.stack.push(1).expect('push failed');
        assert(vm.exec_return().is_ok(), 'Exec return failed');
        let return_data = vm.return_data();
        let parsed_return_data: u256 = return_data
            .from_be_bytes_partial()
            .expect('Failed to parse return data');
        assert(256 == parsed_return_data, 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');
        assert_eq!(vm.error, false);
    }

    #[test]
    fn test_exec_call() {
        // Given

        // Set vm bytecode
        // (call 0xffffff 0xabfa740ccd 0 0 0 0 1)
        let bytecode = [
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x64,
            0xab,
            0xfa,
            0x74,
            0x0c,
            0xcd,
            0x62,
            0xff,
            0xff,
            0xff,
            // CALL
            0xf1,
            0x00
        ].span();
        let code_hash = bytecode.compute_keccak256_hash();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        let caller_account = Account {
            address: vm.message().target,
            balance: 0,
            code: bytecode,
            code_hash: code_hash,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(caller_account);

        // Deploy bytecode at 0xabfa740ccd
        // SSTORE 0x42 at 0x42
        let eth_address: EthAddress = 0xabfa740ccd_u256.into();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let deployed_bytecode = [
            0x60,
            0x01,
            0x60,
            0x01,
            0x01,
            0x60,
            0x00,
            0x53,
            0x60,
            0x42,
            0x60,
            0x42,
            0x55,
            0x60,
            0x20,
            0x60,
            0x00,
            0xf3
        ].span();
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 0,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(contract_account);

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert!(!vm.is_error());
        assert!(!vm.is_running());
        let storage_val = vm.env.state.read_state(contract_account.address.evm, 0x42);
        assert_eq!(storage_val, 0x42);
    }

    #[test]
    fn test_should_fail_exec_staticcall() {
        // Given

        // Set vm bytecode
        // (staticcall 0xffffff 0xabfa740ccd 0 0 0 0 1)
        let bytecode = [
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x64,
            0xab,
            0xfa,
            0x74,
            0x0c,
            0xcd,
            0x62,
            0xff,
            0xff,
            0xff,
            // STATICCALL
            0xfa,
            0x00
        ].span();
        let code_hash = bytecode.compute_keccak256_hash();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        let caller_account = Account {
            address: vm.message().target,
            balance: 0,
            code: bytecode,
            code_hash: code_hash,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(caller_account);

        // Deploy bytecode at 0xabfa740ccd
        // SSTORE 0x42 at 0x42
        let eth_address: EthAddress = 0xabfa740ccd_u256.into();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let deployed_bytecode = [
            0x60,
            0x01,
            0x60,
            0x01,
            0x01,
            0x60,
            0x00,
            0x53,
            0x60,
            0x42,
            0x60,
            0x42,
            0x55,
            0x60,
            0x20,
            0x60,
            0x00,
            0xf3
        ].span();
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 0,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(contract_account);

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert!(!vm.is_error());
        assert!(!vm.is_running());
        assert_eq!(vm.stack.peek().unwrap(), 0); // STATICCALL should fail because of SSTORE
    }


    #[test]
    fn test_exec_call_code() {
        // Given
        // Set vm bytecode
        // (callcode 0xffffff 0x1234 0 0 0 0 1)
        let bytecode = [
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x61,
            0x12,
            0x34,
            0x62,
            0xff,
            0xff,
            0xff,
            // CALLCODE
            0xf2,
            0x00
        ].span();
        let _code_hash = bytecode.compute_keccak256_hash();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        let eoa_account = Account {
            address: vm.message().target,
            balance: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(eoa_account);

        // Deploy bytecode at 0x1234
        // SSTORE 0x42 at 0x42
        let deployed_bytecode = [
            0x60,
            0x01,
            0x60,
            0x01,
            0x01,
            0x60,
            0x00,
            0x53,
            0x60,
            0x42,
            0x60,
            0x42,
            0x55,
            0x60,
            0x20,
            0x60,
            0x00,
            0xf3
        ].span();
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let eth_address: EthAddress = 0x1234.try_into().unwrap();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 0,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(contract_account);

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert!(!vm.is_error());
        assert!(!vm.is_running());

        let storage_val = vm.env.state.read_state(vm.message.target.evm, 0x42);

        assert_eq!(storage_val, 0x42);
    }

    #[test]
    fn test_exec_delegatecall() {
        // Given

        // Set vm bytecode
        // (delegatecall 0xffffff 0x1234 0 0 0 0 1)
        let bytecode = [
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x61,
            0x12,
            0x34,
            0x62,
            0xff,
            0xff,
            0xff,
            // DELEGATECALL
            0xf4,
            0x00
        ].span();
        let _code_hash = bytecode.compute_keccak256_hash();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        let eoa_account = Account {
            address: vm.message().target,
            balance: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(eoa_account);

        // SSTORE 0x42 at 0x42
        let deployed_bytecode = [
            0x60,
            0x01,
            0x60,
            0x01,
            0x01,
            0x60,
            0x00,
            0x53,
            0x60,
            0x42,
            0x60,
            0x42,
            0x55,
            0x60,
            0x20,
            0x60,
            0x00,
            0xf3
        ].span();
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let eth_address: EthAddress = 0x1234.try_into().unwrap();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 0,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        vm.env.state.set_account(contract_account);

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert!(!vm.is_error());
        assert!(!vm.is_running());

        let storage_val = vm.env.state.read_state(vm.message.target.evm, 0x42);

        assert_eq!(storage_val, 0x42);
    }

    //! In the exec_create tests, we query the balance of the contract being created by doing a
    //! starknet_call to the native token.
    //! Thus, we must store the native token address in the Kakarot storage preemptively.
    //! As such, the address computation uses the uninitialized account class.
    #[test]
    fn test_exec_create_no_value_transfer() {
        // Given
        setup_test_environment();

        let deployed_bytecode = [0xff].span();
        let eth_address: EthAddress = evm_address();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, uninitialized_account()
        );
        let origin_account = Account {
            address: Address {
                evm: origin(),
                starknet: compute_starknet_address(
                    test_address(), origin(), uninitialized_account()
                )
            },
            balance: 2,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 2,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        let mut vm = VMBuilderTrait::new_with_presets()
            .with_target(contract_account.address)
            .build();
        vm.env.state.set_account(contract_account);
        vm.env.state.set_account(origin_account);

        // Load into memory the bytecode of Storage.sol
        let storage_initcode = storage_evm_initcode();
        vm.memory.store_n_with_expansion(storage_initcode, 0);

        vm.stack.push(storage_initcode.len().into()).unwrap();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');

        // When
        start_mock_call::<u256>(native_token(), selector!("balance_of"), 0);
        vm.exec_create().unwrap();
        EVMTrait::execute_code(ref vm);

        // computed using `compute_create_address` script
        // run `bun run compute_create_address` -> CREATE -> EthAddress = evm_address() ->
        //nonce = 1
        let account = vm
            .env
            .state
            .get_account(0x930b3d8D35621F2e27Db700cA5D16Df771642fdD.try_into().unwrap());

        assert_eq!(account.nonce(), 1);
        assert_eq!(account.code, storage_evm_bytecode());
        assert_eq!(account.balance(), 0);

        let deployer = vm.env.state.get_account(eth_address);
        assert_eq!(deployer.nonce(), 2);
        assert_eq!(deployer.balance(), 2);
    }
    //TODO add test with value transfer

    #[test]
    fn test_exec_create_failure() {
        // Given
        setup_test_environment();

        let deployed_bytecode = [0xFF].span();
        let eth_address: EthAddress = evm_address();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let origin_account = Account {
            address: Address {
                evm: origin(),
                starknet: compute_starknet_address(
                    test_address(), origin(), uninitialized_account()
                ),
            },
            balance: 2,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let deployer = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 2,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        let mut vm = VMBuilderTrait::new_with_presets().with_target(deployer.address).build();
        vm.env.state.set_account(deployer);
        vm.env.state.set_account(origin_account);

        // Load into memory the bytecode to init, which is the revert opcode
        let revert_initcode = [0xFD].span();
        vm.memory.store_n_with_expansion(revert_initcode, 0);

        vm.stack.push(revert_initcode.len().into()).unwrap();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');

        // When
        start_mock_call::<u256>(native_token(), selector!("balance_of"), 0);
        vm.exec_create().expect('exec_create failed');
        EVMTrait::execute_code(ref vm);

        let expected_address = 0x930b3d8D35621F2e27Db700cA5D16Df771642fdD.try_into().unwrap();

        // computed using `compute_create_address` script
        let account = vm.env.state.get_account(expected_address);
        assert_eq!(account.nonce(), 0);
        assert_eq!(account.code.len(), 0);
        assert_eq!(account.balance(), 0);

        let deployer = vm.env.state.get_account(eth_address);
        assert_eq!(deployer.nonce(), 2);
        assert_eq!(deployer.balance(), 2);
    }

    #[test]
    fn test_exec_create2() {
        // Given
        setup_test_environment();

        let deployed_bytecode = [0xff].span();
        let eth_address: EthAddress = evm_address();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let origin_account = Account {
            address: Address {
                evm: origin(),
                starknet: compute_starknet_address(
                    test_address(), origin(), uninitialized_account()
                ),
            },
            balance: 2,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 2,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        let mut vm = VMBuilderTrait::new_with_presets()
            .with_caller(contract_account.address)
            .build();

        vm.env.state.set_account(origin_account);
        vm.env.state.set_account(contract_account);

        // Load into memory the bytecode of Storage.sol
        let storage_initcode = storage_evm_initcode();
        vm.memory.store_n_with_expansion(storage_initcode, 0);

        vm.stack.push(0).expect('push failed');
        vm.stack.push(storage_initcode.len().into()).unwrap();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');

        // When
        start_mock_call::<u256>(native_token(), selector!("balance_of"), 0);
        vm.exec_create2().unwrap();
        EVMTrait::execute_code(ref vm);

        assert!(!vm.is_running() && !vm.is_error());

        // Add SNJS script to precompute the address of the Storage.sol contract
        //     import { getContractAddress } from 'viem'

        // const address = getContractAddress({
        //   bytecode:
        //
        // '0x608060405234801561000f575f80fd5b506101438061001d5f395ff3fe608060405234801561000f575f80fd5b5060043610610034575f3560e01c80632e64cec1146100385780636057361d14610056575b5f80fd5b610040610072565b60405161004d919061009b565b60405180910390f35b610070600480360381019061006b91906100e2565b61007a565b005b5f8054905090565b805f8190555050565b5f819050919050565b61009581610083565b82525050565b5f6020820190506100ae5f83018461008c565b92915050565b5f80fd5b6100c181610083565b81146100cb575f80fd5b50565b5f813590506100dc816100b8565b92915050565b5f602082840312156100f7576100f66100b4565b5b5f610104848285016100ce565b9150509291505056fea2646970667358221220b5c3075f2f2034d039a227fac6dd314b052ffb2b3da52c7b6f5bc374d528ed3664736f6c63430008140033',
        //   from: '0x00000000000000000065766d5f61646472657373', opcode: 'CREATE2',
        //salt: '0x00',
        // });
        // console.log(address)
        let account = vm
            .env
            .state
            .get_account(0x0f48B8c382B5234b1a92368ee0f6864a429d0Cb8.try_into().unwrap());

        assert(account.nonce() == 1, 'wrong nonce');
        assert(account.code == storage_evm_bytecode(), 'wrong bytecode');
    }

    #[test]
    fn test_exec_selfdestruct_should_fail_if_readonly() {
        // Given
        let deployed_bytecode = [0xff].span();
        let eth_address: EthAddress = evm_address();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 2,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        let mut vm = VMBuilderTrait::new_with_presets()
            .with_target(contract_account.address)
            .with_read_only()
            .build();
        vm.env.state.set_account(contract_account);

        // When
        vm.stack.push(contract_account.address.evm.into()).unwrap();
        let res = vm.exec_selfdestruct();
        // Then
        assert!(res.is_err())
    }

    #[test]
    fn test_exec_selfdestruct_should_burn_tokens_if_created_same_tx_and_recipient_self() {
        // Given
        let deployed_bytecode = [0xff].span();
        let eth_address: EthAddress = evm_address();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 2,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: true,
            selfdestruct: false,
        };
        let burn_account = Account {
            address: Address {
                evm: 0.try_into().unwrap(),
                starknet: compute_starknet_address(
                    test_address(), 0.try_into().unwrap(), 0.try_into().unwrap()
                ),
            },
            balance: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };
        let mut vm = VMBuilderTrait::new_with_presets()
            .with_target(contract_account.address)
            .build();
        vm.env.state.set_account(burn_account);
        vm.env.state.set_account(contract_account);

        // When
        vm.stack.push(contract_account.address.evm.into()).unwrap();
        vm.exec_selfdestruct().expect('selfdestruct failed');

        // Then
        let contract_account = vm.env.state.get_account(contract_account.address.evm);
        assert!(contract_account.is_selfdestruct());
        assert_eq!(contract_account.balance(), 0);

        let burn_account = vm.env.state.get_account(burn_account.address.evm);
        assert_eq!(burn_account.balance(), 2);
    }

    #[test]
    fn test_exec_selfdestruct_should_transfer_balance_to_recipient() {
        // Given
        let deployed_bytecode = [0xff].span();
        let eth_address: EthAddress = evm_address();
        let starknet_address = compute_starknet_address(
            test_address(), eth_address, 0.try_into().unwrap()
        );
        let code_hash = deployed_bytecode.compute_keccak256_hash();
        let contract_account = Account {
            address: Address { evm: eth_address, starknet: starknet_address, },
            balance: 2,
            code: deployed_bytecode,
            code_hash: code_hash,
            nonce: 1,
            is_created: false,
            selfdestruct: false,
        };
        let recipient = Account {
            address: Address {
                evm: 'recipient'.try_into().unwrap(),
                starknet: compute_starknet_address(
                    test_address(), 'recipient'.try_into().unwrap(), 0.try_into().unwrap()
                ),
            },
            balance: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            nonce: 0,
            is_created: false,
            selfdestruct: false,
        };

        let mut vm = VMBuilderTrait::new_with_presets()
            .with_target(contract_account.address)
            .build();
        vm.env.state.set_account(contract_account);
        vm.env.state.set_account(recipient);

        // When
        vm.stack.push(recipient.address.evm.into()).unwrap();
        vm.exec_selfdestruct().expect('selfdestruct failed');

        // Then
        let contract_account = vm.env.state.get_account(contract_account.address.evm);
        assert!(contract_account.is_selfdestruct());
        assert_eq!(contract_account.balance(), 0);

        let recipient = vm.env.state.get_account(recipient.address.evm);
        assert_eq!(recipient.balance(), 2);
    }
}
