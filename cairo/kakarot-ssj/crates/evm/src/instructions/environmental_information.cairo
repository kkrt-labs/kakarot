use core::num::traits::OverflowingAdd;
use core::num::traits::Zero;
use core::num::traits::{CheckedAdd, CheckedSub};
use crate::errors::{ensure, EVMError};
use crate::gas;
use crate::memory::MemoryTrait;
use crate::model::account::{AccountTrait};
use crate::model::vm::{VM, VMTrait};
use crate::model::{AddressTrait};
use crate::stack::StackTrait;
use crate::state::StateTrait;
use utils::helpers::bytes_32_words_size;
use utils::set::SetTrait;
use utils::traits::bytes::FromBytes;
use utils::traits::{EthAddressIntoU256};


#[generate_trait]
pub impl EnvironmentInformationImpl of EnvironmentInformationTrait {
    /// 0x30 - ADDRESS
    /// Get address of currently executing account.
    /// # Specification: https://www.evm.codes/#30?fork=shanghai
    fn exec_address(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.message().target.evm.into())
    }

    /// 0x31 - BALANCE opcode.
    /// Get ETH balance of the specified address.
    /// # Specification: https://www.evm.codes/#31?fork=shanghai
    fn exec_balance(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        // GAS
        if self.accessed_addresses.contains(evm_address) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_addresses.add(evm_address);
            self.charge_gas(gas::COLD_ACCOUNT_ACCESS_COST)?
        }

        let balance = self.env.state.get_account(evm_address).balance();
        self.stack.push(balance)
    }

    /// 0x32 - ORIGIN
    /// Get execution origination address.
    /// # Specification: https://www.evm.codes/#32?fork=shanghai
    fn exec_origin(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.env.origin.evm.into())
    }

    /// 0x33 - CALLER
    /// Get caller address.
    /// # Specification: https://www.evm.codes/#33?fork=shanghai
    fn exec_caller(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.message().caller.evm.into())
    }

    /// 0x34 - CALLVALUE
    /// Get deposited value by the instruction/transaction responsible for this execution.
    /// # Specification: https://www.evm.codes/#34?fork=shanghai
    fn exec_callvalue(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.message().value)
    }

    /// 0x35 - CALLDATALOAD
    /// Push a word from the calldata onto the stack.
    /// # Specification: https://www.evm.codes/#35?fork=shanghai
    fn exec_calldataload(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;

        // Don't error out if the offset is too big. It should just push 0.
        let offset: usize = self.stack.pop_saturating_usize()?;

        let calldata = self.message().data;
        let calldata_len = calldata.len();

        // All bytes after the end of the calldata are set to 0.
        let bytes_len = match calldata_len.checked_sub(offset) {
            Option::None => { return self.stack.push(0); },
            Option::Some(remaining_len) => {
                if remaining_len == 0 {
                    return self.stack.push(0);
                }
                core::cmp::min(32, remaining_len)
            }
        };

        // Slice the calldata
        let sliced = calldata.slice(offset, bytes_len);

        let mut data_to_load: u256 = sliced
            .from_be_bytes_partial()
            .expect('Failed to parse calldata');

        // Fill the rest of the data to load with zeros
        // TODO: optimize once we have dw-based exponentiation
        for _ in 0..32 - bytes_len {
            data_to_load *= 256;
        };
        self.stack.push(data_to_load)
    }

    /// 0x36 - CALLDATASIZE
    /// Get the size of return data.
    /// # Specification: https://www.evm.codes/#36?fork=shanghai
    fn exec_calldatasize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        let size: u256 = self.message().data.len().into();
        self.stack.push(size)
    }

    /// 0x37 - CALLDATACOPY operation
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#37?fork=shanghai
    fn exec_calldatacopy(ref self: VM) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_saturating_usize()?;
        let offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        let words_size = bytes_32_words_size(size).into();
        let copy_gas_cost = gas::COPY * words_size;
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(dest_offset, size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);

        let total_cost = gas::VERYLOW
            .checked_add(copy_gas_cost)
            .ok_or(EVMError::OutOfGas)?
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;

        let calldata: Span<u8> = self.message().data;
        copy_bytes_to_memory(ref self, calldata, dest_offset, offset, size);
        Result::Ok(())
    }

    /// 0x38 - CODESIZE
    /// Get size of bytecode running in current environment.
    /// # Specification: https://www.evm.codes/#38?fork=shanghai
    fn exec_codesize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        let size: u256 = self.message().code.len().into();
        self.stack.push(size)
    }

    /// 0x39 - CODECOPY
    /// Copies slice of bytecode to memory.
    /// # Specification: https://www.evm.codes/#39?fork=shanghai
    fn exec_codecopy(ref self: VM) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_saturating_usize()?;
        let offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        let words_size = bytes_32_words_size(size).into();
        let copy_gas_cost = gas::COPY * words_size;
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(dest_offset, size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);

        let total_cost = gas::VERYLOW
            .checked_add(copy_gas_cost)
            .ok_or(EVMError::OutOfGas)?
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;

        let bytecode: Span<u8> = self.message().code;

        copy_bytes_to_memory(ref self, bytecode, dest_offset, offset, size);
        Result::Ok(())
    }

    /// 0x3A - GASPRICE
    /// Get price of gas in current environment.
    /// # Specification: https://www.evm.codes/#3a?fork=shanghai
    fn exec_gasprice(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.env.gas_price.into())
    }

    /// 0x3B - EXTCODESIZE
    /// Get size of an account's code.
    /// # Specification: https://www.evm.codes/#3b?fork=shanghai
    fn exec_extcodesize(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        // GAS
        if self.accessed_addresses.contains(evm_address) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_addresses.add(evm_address);
            self.charge_gas(gas::COLD_ACCOUNT_ACCESS_COST)?
        }

        let account = self.env.state.get_account(evm_address);
        self.stack.push(account.code.len().into())
    }

    /// 0x3C - EXTCODECOPY
    /// Copy an account's code to memory
    /// # Specification: https://www.evm.codes/#3c?fork=shanghai
    fn exec_extcodecopy(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;
        let dest_offset = self.stack.pop_saturating_usize()?;
        let offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        // GAS
        let words_size = bytes_32_words_size(size).into();
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(dest_offset, size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);
        let copy_gas_cost = gas::COPY * words_size;
        let access_gas_cost = if self.accessed_addresses.contains(evm_address) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(evm_address);
            gas::COLD_ACCOUNT_ACCESS_COST
        };
        let total_cost = access_gas_cost
            .checked_add(copy_gas_cost)
            .ok_or(EVMError::OutOfGas)?
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;

        let bytecode = self.env.state.get_account(evm_address).code;
        copy_bytes_to_memory(ref self, bytecode, dest_offset, offset, size);
        Result::Ok(())
    }

    /// 0x3D - RETURNDATASIZE
    /// Get the size of return data.
    /// # Specification: https://www.evm.codes/#3d?fork=shanghai
    fn exec_returndatasize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        let size = self.return_data().len();
        self.stack.push(size.into())
    }

    /// 0x3E - RETURNDATACOPY
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#3e?fork=shanghai
    fn exec_returndatacopy(ref self: VM) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_saturating_usize()?;
        let offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.
        let return_data: Span<u8> = self.return_data();

        let (last_returndata_index, overflow) = offset.overflowing_add(size);
        if overflow {
            return Result::Err(EVMError::ReturnDataOutOfBounds);
        }
        ensure(!(last_returndata_index > return_data.len()), EVMError::ReturnDataOutOfBounds)?;

        let words_size = bytes_32_words_size(size).into();
        let copy_gas_cost = gas::COPY * words_size;

        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(dest_offset, size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);
        let total_cost = gas::VERYLOW
            .checked_add(copy_gas_cost)
            .ok_or(EVMError::OutOfGas)?
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;

        let data_to_copy: Span<u8> = return_data.slice(offset, size);
        self.memory.store_n(data_to_copy, dest_offset);

        Result::Ok(())
    }

    /// 0x3F - EXTCODEHASH
    /// Get hash of a contract's code.
    // If the account has no code, return the empty hash:
    // `0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470`
    // If the account does not exist, is a precompile or was destroyed (SELFDESTRUCT), return 0
    // Else return, the hash of the account's code
    /// # Specification: https://www.evm.codes/#3f?fork=shanghai
    fn exec_extcodehash(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        // GAS
        if self.accessed_addresses.contains(evm_address) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_addresses.add(evm_address);
            self.charge_gas(gas::COLD_ACCOUNT_ACCESS_COST)?
        }

        let account = self.env.state.get_account(evm_address);
        // Relevant cases:
        // https://github.com/ethereum/go-ethereum/blob/master/core/vm/instructions.go#L392
        if account.evm_address().is_precompile()
            || (!account.has_code_or_nonce() && account.balance.is_zero()) {
            return self.stack.push(0);
        }
        self.stack.push(account.code_hash)
    }
}

#[inline(always)]
fn copy_bytes_to_memory(
    ref self: VM, bytes: Span<u8>, dest_offset: usize, offset: usize, size: usize
) {
    let bytes_slice = match bytes.len().checked_sub(offset) {
        Option::Some(remaining) => bytes.slice(offset, core::cmp::min(size, remaining)),
        Option::None => [].span()
    };

    self.memory.store_padded_segment(dest_offset, size, bytes_slice);
}


#[cfg(test)]
mod tests {
    use contracts::test_data::counter_evm_bytecode;
    use core::starknet::EthAddress;
    use crate::errors::{EVMError, TYPE_CONVERSION_ERROR};
    use crate::instructions::EnvironmentInformationTrait;
    use crate::memory::{InternalMemoryTrait, MemoryTrait};

    use crate::model::vm::VMTrait;
    use crate::model::{Account, Address};
    use crate::stack::StackTrait;
    use crate::state::StateTrait;
    use crate::test_utils::{VMBuilderTrait, origin, callvalue, gas_price};
    use snforge_std::test_address;
    use utils::constants::EMPTY_KECCAK;
    use utils::helpers::{u256_to_bytes_array, compute_starknet_address};
    use utils::traits::array::ArrayExtTrait;
    use utils::traits::bytes::{U8SpanExTrait};
    use utils::traits::{EthAddressIntoU256};


    mod test_internals {
        use crate::memory::MemoryTrait;
        use crate::test_utils::VMBuilderTrait;
        use super::super::copy_bytes_to_memory;

        fn test_copy_bytes_to_memory_helper(
            bytes: Span<u8>, dest_offset: usize, offset: usize, size: usize, expected: Span<u8>
        ) {
            // Given
            let mut vm = VMBuilderTrait::new_with_presets().build();

            // When
            copy_bytes_to_memory(ref vm, bytes, dest_offset, offset, size);

            // Then
            let mut result = ArrayTrait::new();
            vm.memory.load_n(size, ref result, dest_offset);
            assert_eq!(result.span(), expected);
        }

        #[test]
        fn test_copy_bytes_to_memory_normal_case() {
            let bytes = [1, 2, 3, 4, 5].span();
            test_copy_bytes_to_memory_helper(bytes, 0, 0, 5, bytes);
        }

        #[test]
        fn test_copy_bytes_to_memory_with_offset() {
            let bytes = [1, 2, 3, 4, 5].span();
            test_copy_bytes_to_memory_helper(bytes, 0, 2, 3, [3, 4, 5].span());
        }

        #[test]
        fn test_copy_bytes_to_memory_size_larger_than_remaining_bytes() {
            let bytes = [1, 2, 3, 4, 5].span();
            test_copy_bytes_to_memory_helper(bytes, 0, 3, 5, [4, 5, 0, 0, 0].span());
        }

        #[test]
        fn test_copy_bytes_to_memory_offset_out_of_bounds() {
            let bytes = [1, 2, 3, 4, 5].span();
            test_copy_bytes_to_memory_helper(bytes, 0, 10, 5, [0, 0, 0, 0, 0].span());
        }

        #[test]
        fn test_copy_bytes_to_memory_zero_size() {
            let bytes = [1, 2, 3, 4, 5].span();
            test_copy_bytes_to_memory_helper(bytes, 0, 0, 0, [].span());
        }

        #[test]
        fn test_copy_bytes_to_memory_non_zero_dest_offset() {
            let bytes = [1, 2, 3, 4, 5].span();
            test_copy_bytes_to_memory_helper(bytes, 10, 0, 5, bytes);
        }
    }

    // *************************************************************************
    // 0x30: ADDRESS
    // *************************************************************************

    #[test]
    fn test_address_basic() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_address().expect('exec_address failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop_eth_address().unwrap(), vm.message().target.evm.into());
    }

    // *************************************************************************
    // 0x31: BALANCE
    // *************************************************************************
    #[test]
    fn test_exec_balance_eoa() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 400,
            nonce: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(vm.message.target.evm.into()).unwrap();

        // When
        vm.exec_balance().expect('exec_balance failed');

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 400);
    }

    // *************************************************************************
    // 0x33: CALLER
    // *************************************************************************
    #[test]
    fn test_caller() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_caller().expect('exec_caller failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), origin().into());
    }


    // *************************************************************************
    // 0x32: ORIGIN
    // *************************************************************************
    #[test]
    fn test_origin_nested_ctx() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_origin().expect('exec_origin failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), vm.env.origin.evm.into());
    }


    // *************************************************************************
    // 0x34: CALLVALUE
    // *************************************************************************
    #[test]
    fn test_exec_callvalue() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_callvalue().expect('exec_callvalue failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop().unwrap(), callvalue());
    }

    // *************************************************************************
    // 0x35: CALLDATALOAD
    // *************************************************************************

    #[test]
    fn test_calldataload() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = 0;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();
        assert_eq!(result, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_calldataload_with_offset() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );

        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = 31;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();

        assert_eq!(result, 0xFF00000000000000000000000000000000000000000000000000000000000000);
    }

    #[test]
    fn test_calldataload_with_offset_beyond_calldata() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = calldata.len() + 1;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();
        assert_eq!(result, 0);
    }

    #[test]
    fn test_calldataload_with_function_selector() {
        // Given
        let calldata = array![0x6d, 0x4c, 0xe6, 0x3c];
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = 0;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();
        assert_eq!(result, 0x6d4ce63c00000000000000000000000000000000000000000000000000000000);
    }


    #[test]
    fn test_calldataload_with_offset_bigger_usize_succeeds() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();
        let offset: u256 = 5000000000;
        vm.stack.push(offset).expect('push failed');

        // When
        let result = vm.exec_calldataload();

        // Then
        assert!(result.is_ok());
        assert_eq!(vm.stack.pop().unwrap(), 0);
    }

    // *************************************************************************
    // 0x36: CALLDATASIZE
    // *************************************************************************

    #[test]
    fn test_calldata_size() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let calldata: Span<u8> = vm.message.data;

        // When
        vm.exec_calldatasize().expect('exec_calldatasize failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), calldata.len().into());
    }

    // *************************************************************************
    // 0x37: CALLDATACOPY
    // *************************************************************************

    #[test]
    fn test_calldatacopy_type_conversion_error() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');

        // When
        let res = vm.exec_calldatacopy();

        // Then
        assert!(res.is_err());
        assert_eq!(res.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    #[test]
    fn test_calldatacopy_basic() {
        test_calldatacopy(32, 0, 3, [4, 5, 6].span());
    }

    #[test]
    fn test_calldatacopy_with_out_of_bound_bytes() {
        // For out of bound bytes, 0s will be copied.
        let mut expected = array![4, 5, 6];
        expected.append_n(0, 5);

        test_calldatacopy(32, 0, 8, expected.span());
    }

    #[test]
    fn test_calldatacopy_with_out_of_bound_bytes_multiple_words() {
        // For out of bound bytes, 0s will be copied.
        let mut expected = array![4, 5, 6];
        expected.append_n(0, 31);

        test_calldatacopy(32, 0, 34, expected.span());
    }

    fn test_calldatacopy(dest_offset: u32, offset: u32, mut size: u32, expected: Span<u8>) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let _calldata: Span<u8> = vm.message.data;

        vm.stack.push(size.into()).expect('push failed');
        vm.stack.push(offset.into()).expect('push failed');
        vm.stack.push(dest_offset.into()).expect('push failed');

        // Memory initialization with a value to verify that if the offset + size is out of the
        // bound bytes, 0's have been copied.
        // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
        for i in 0
            ..(size / 32)
                + 1 {
                    vm
                        .memory
                        .store(
                            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                            dest_offset + (i * 32)
                        );

                    let initial: u256 = vm.memory.load_internal(dest_offset + (i * 32)).into();

                    assert_eq!(
                        initial, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                    );
                };

        // When
        vm.exec_calldatacopy().expect('exec_calldatacopy failed');

        // Then
        assert!(vm.stack.is_empty());

        let mut results: Array<u8> = ArrayTrait::new();
        vm.memory.load_n_internal(size, ref results, dest_offset);

        assert_eq!(results.span(), expected);
    }

    // *************************************************************************
    // 0x38: CODESIZE
    // *************************************************************************

    #[test]
    fn test_codesize() {
        // Given
        let bytecode: Span<u8> = [1, 2, 3, 4, 5].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        // When
        vm.exec_codesize().expect('exec_codesize failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop().unwrap(), bytecode.len().into());
    }

    // *************************************************************************
    // 0x39: CODECOPY
    // *************************************************************************

    #[test]
    fn test_codecopy_type_conversion_error() {
        // Given
        let bytecode: Span<u8> = [1, 2, 3, 4, 5].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');

        // When
        let res = vm.exec_codecopy();

        // Then
        assert!(res.is_err());
        assert_eq!(res.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    #[test]
    fn test_codecopy_basic() {
        test_codecopy(32, 0, 0);
    }

    #[test]
    fn test_codecopy_with_out_of_bound_bytes() {
        test_codecopy(32, 0, 8);
    }

    #[test]
    fn test_codecopy_with_out_of_bound_offset() {
        test_codecopy(0, 0xFFFFFFFE, 2);
    }

    fn test_codecopy(dest_offset: u32, offset: u32, mut size: u32) {
        // Given
        let bytecode: Span<u8> = [1, 2, 3, 4, 5].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        if (size == 0) {
            size = bytecode.len() - offset;
        }

        vm.stack.push(size.into()).expect('push failed');
        vm.stack.push(offset.into()).expect('push failed');
        vm.stack.push(dest_offset.into()).expect('push failed');

        vm
            .memory
            .store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, dest_offset);
        let initial: u256 = vm.memory.load_internal(dest_offset).into();
        assert_eq!(initial, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        // When
        vm.exec_codecopy().expect('exec_codecopy failed');

        // Then
        assert!(vm.stack.is_empty());

        let result: u256 = vm.memory.load_internal(dest_offset).into();
        let mut results: Array<u8> = u256_to_bytes_array(result);

        for i in 0
            ..size {
                // For out of bound bytes, 0s will be copied.
                if (i + offset >= bytecode.len()) {
                    assert_eq!(*results[i], 0);
                } else {
                    assert_eq!(*results[i], *bytecode[i + offset]);
                }
            };
    }

    // *************************************************************************
    // 0x3A: GASPRICE
    // *************************************************************************

    #[test]
    fn test_gasprice() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_gasprice().expect('exec_gasprice failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), gas_price().into());
    }

    // *************************************************************************
    // 0x3B - EXTCODESIZE
    // *************************************************************************
    #[test]
    fn test_exec_extcodesize_should_push_bytecode_len_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodesize().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }

    #[test]
    fn test_exec_extcodesize_should_push_bytecode_len() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let bytecode = [0xff; 350].span();
        let code_hash = bytecode.compute_keccak256_hash();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: bytecode,
            code_hash,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodesize().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 350);
    }

    // *************************************************************************
    // 0x3C - EXTCODECOPY
    // *************************************************************************

    #[test]
    fn test_exec_extcodecopy_should_copy_code_of_input_account() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let bytecode = counter_evm_bytecode();
        let code_hash = bytecode.compute_keccak256_hash();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: bytecode,
            code_hash,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);

        vm.stack.push(account.address.evm.into()).expect('push failed');
        // size
        vm.stack.push(50).expect('push failed');
        // offset
        vm.stack.push(200).expect('push failed');
        // destOffset (memory offset)
        vm.stack.push(20).expect('push failed');
        vm.stack.push(account.address.evm.into()).unwrap();

        // When
        vm.exec_extcodecopy().unwrap();

        // Then
        let mut bytecode_slice = array![];
        vm.memory.load_n(50, ref bytecode_slice, 20);
        assert_eq!(bytecode_slice.span(), account.code.slice(200, 50));
    }

    #[test]
    fn test_exec_extcodecopy_ca_offset_out_of_bounds_should_return_zeroes() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let bytecode = counter_evm_bytecode();
        let code_hash = bytecode.compute_keccak256_hash();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: bytecode,
            code_hash,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // size
        vm.stack.push(5).expect('push failed');
        // offset
        vm.stack.push(5000).expect('push failed');
        // destOffset
        vm.stack.push(20).expect('push failed');
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodecopy().unwrap();

        // Then
        let mut bytecode_slice = array![];
        vm.memory.load_n(5, ref bytecode_slice, 20);
        assert_eq!(bytecode_slice.span(), [0, 0, 0, 0, 0].span());
    }

    #[test]
    fn test_exec_returndatasize() {
        // Given
        let return_data: Array<u8> = array![1, 2, 3, 4, 5];
        let size = return_data.len();

        let mut vm = VMBuilderTrait::new_with_presets()
            .with_return_data(return_data.span())
            .build();

        vm.exec_returndatasize().expect('exec_returndatasize failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop().unwrap(), size.into());
    }

    // *************************************************************************
    // 0x3E: RETURNDATACOPY
    // *************************************************************************

    #[test]
    fn test_returndata_copy_type_conversion_error() {
        // Given
        let return_data: Array<u8> = array![1, 2, 3, 4, 5];
        let mut vm = VMBuilderTrait::new_with_presets()
            .with_return_data(return_data.span())
            .build();

        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');

        // When
        let res = vm.exec_returndatacopy();

        // Then
        assert_eq!(res.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    fn test_returndatacopy_helper(
        return_data: Span<u8>,
        dest_offset: u32,
        offset: u32,
        size: u32,
        expected_result: Result<Span<u8>, EVMError>
    ) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_return_data(return_data).build();

        vm.stack.push(size.into()).expect('push failed');
        vm.stack.push(offset.into()).expect('push failed');
        vm.stack.push(dest_offset.into()).expect('push failed');

        // When
        let res = vm.exec_returndatacopy();

        // Then
        match expected_result {
            Result::Ok(expected) => {
                assert!(res.is_ok());
                let mut result = ArrayTrait::new();
                vm
                    .memory
                    .load_n(size.try_into().unwrap(), ref result, dest_offset.try_into().unwrap());
                assert_eq!(result.span(), expected);
            },
            Result::Err(expected_error) => {
                assert!(res.is_err());
                assert_eq!(res.unwrap_err(), expected_error);
            }
        }
    }

    #[test]
    fn test_returndatacopy_basic() {
        let return_data = array![1, 2, 3, 4, 5].span();
        test_returndatacopy_helper(return_data, 0, 0, 5, Result::Ok(return_data));
    }

    #[test]
    fn test_returndatacopy_with_offset() {
        let return_data = array![1, 2, 3, 4, 5].span();
        test_returndatacopy_helper(return_data, 0, 2, 3, Result::Ok([3, 4, 5].span()));
    }

    #[test]
    fn test_returndatacopy_out_of_bounds() {
        let return_data = array![1, 2, 3, 4, 5].span();
        test_returndatacopy_helper(
            return_data, 0, 3, 3, Result::Err(EVMError::ReturnDataOutOfBounds)
        );
    }

    #[test]
    fn test_returndatacopy_overflowing_add() {
        let return_data = array![1, 2, 3, 4, 5].span();
        test_returndatacopy_helper(
            return_data, 0, 0xFFFFFFFF, 1, Result::Err(EVMError::ReturnDataOutOfBounds)
        );
    }

    // *************************************************************************
    // 0x3F: EXTCODEHASH
    // *************************************************************************
    #[test]
    fn test_exec_extcodehash_precompile() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let precompile_evm_address: EthAddress = evm::precompiles::LAST_ETHEREUM_PRECOMPILE_ADDRESS
            .try_into()
            .unwrap();
        let precompile_starknet_address = compute_starknet_address(
            test_address(), precompile_evm_address, 0.try_into().unwrap()
        );
        let account = Account {
            address: Address {
                evm: precompile_evm_address, starknet: precompile_starknet_address,
            },
            balance: 1,
            nonce: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(precompile_evm_address.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }

    #[test]
    fn test_exec_extcodehash_empty_account() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 0,
            nonce: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }

    #[test]
    fn test_exec_extcodehash_no_bytecode() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), EMPTY_KECCAK);
    }

    #[test]
    fn test_exec_extcodehash_with_bytecode() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let bytecode = counter_evm_bytecode();
        let code_hash = bytecode.compute_keccak256_hash();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: bytecode,
            code_hash,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(
            vm.stack.peek() // extcodehash(Counter.sol) :=
            // 0x82abf19c13d2262cc530f54956af7e4ec1f45f637238ed35ed7400a3409fd275 (source:
            // remix)
            // <https://emn178.github.io/online-tools/keccak_256.html?input=608060405234801561000f575f80fd5b506004361061004a575f3560e01c806306661abd1461004e578063371303c01461006c5780636d4ce63c14610076578063b3bcfa8214610094575b5f80fd5b61005661009e565b60405161006391906100f7565b60405180910390f35b6100746100a3565b005b61007e6100bd565b60405161008b91906100f7565b60405180910390f35b61009c6100c5565b005b5f5481565b60015f808282546100b4919061013d565b92505081905550565b5f8054905090565b60015f808282546100d69190610170565b92505081905550565b5f819050919050565b6100f1816100df565b82525050565b5f60208201905061010a5f8301846100e8565b92915050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f610147826100df565b9150610152836100df565b925082820190508082111561016a57610169610110565b5b92915050565b5f61017a826100df565b9150610185836100df565b925082820390508181111561019d5761019c610110565b5b9291505056fea26469706673582212207e792fcff28a4bf0bad8675c5bc2288b07835aebaa90b8dc5e0df19183fb72cf64736f6c63430008160033&input_type=hex>
            .unwrap(),
            0xec976f44607e73ea88910411e3da156757b63bea5547b169e1e0d733443f73b0,
        );
    }
}
