use core::cmp::max;
use crate::backend::starknet_backend::fetch_original_storage;
//! Stack Memory Storage and Flow Operations.
use crate::errors::{EVMError, ensure};
use crate::gas;
use crate::memory::MemoryTrait;
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;
use crate::state::StateTrait;
use utils::helpers::bytes_32_words_size;
use utils::set::SetTrait;

#[inline(always)]
fn jump(ref self: VM, index: usize) -> Result<(), EVMError> {
    match self.message().code.get(index) {
        Option::Some(_) => { ensure(self.is_valid_jump(index), EVMError::InvalidJump)?; },
        Option::None => { return Result::Err(EVMError::InvalidJump); }
    }
    self.set_pc(index);
    Result::Ok(())
}

#[generate_trait]
pub impl MemoryOperation of MemoryOperationTrait {
    /// 0x50 - POP operation.
    /// Pops the first item on the stack (top of the stack).
    /// # Specification: https://www.evm.codes/#50?fork=shanghai
    fn exec_pop(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        // self.stack.pop() returns a Result<u256, EVMError> so we cannot simply return its result
        self.stack.pop()?;
        Result::Ok(())
    }

    /// MLOAD operation.
    /// Load word from memory and push to stack.
    fn exec_mload(ref self: VM) -> Result<(), EVMError> {
        let offset: usize = self
            .stack
            .pop_usize()?; // Any offset bigger than a usize would MemoryOOG.

        let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, 32)].span())?;
        self.memory.ensure_length(memory_expansion.new_size);
        self.charge_gas(gas::VERYLOW + memory_expansion.expansion_cost)?;

        let result = self.memory.load(offset);
        self.stack.push(result)
    }

    /// 0x52 - MSTORE operation.
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#52?fork=shanghai
    fn exec_mstore(ref self: VM) -> Result<(), EVMError> {
        let offset: usize = self
            .stack
            .pop_usize()?; // Any offset bigger than a usize would MemoryOOG.
        let value: u256 = self.stack.pop()?;
        let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, 32)].span())?;
        self.memory.ensure_length(memory_expansion.new_size);
        self.charge_gas(gas::VERYLOW + memory_expansion.expansion_cost)?;

        self.memory.store(value, offset);
        Result::Ok(())
    }

    /// 0x53 - MSTORE8 operation.
    /// Save single byte to memory
    /// # Specification: https://www.evm.codes/#53?fork=shanghai
    fn exec_mstore8(ref self: VM) -> Result<(), EVMError> {
        let offset = self.stack.pop_usize()?; // Any offset bigger than a usize would MemoryOOG.
        let value = self.stack.pop()?;
        let value: u8 = (value.low & 0xFF).try_into().unwrap();

        let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, 1)].span())?;
        self.memory.ensure_length(memory_expansion.new_size);
        self.charge_gas(gas::VERYLOW + memory_expansion.expansion_cost)?;

        self.memory.store_byte(value, offset);

        Result::Ok(())
    }


    /// 0x54 - SLOAD operation
    /// Load from storage.
    /// # Specification: https://www.evm.codes/#54?fork=shanghai
    fn exec_sload(ref self: VM) -> Result<(), EVMError> {
        let key = self.stack.pop()?;
        let evm_address = self.message().target.evm;

        // GAS
        if self.accessed_storage_keys.contains((evm_address, key)) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_storage_keys.add((evm_address, key));
            self.charge_gas(gas::COLD_SLOAD_COST)?;
        }

        let value = self.env.state.read_state(evm_address, key);
        self.stack.push(value)
    }


    /// 0x55 - SSTORE operation
    /// Save 32-byte word to storage.
    /// # Specification: https://www.evm.codes/#55?fork=shanghai
    fn exec_sstore(ref self: VM) -> Result<(), EVMError> {
        let key = self.stack.pop()?;
        let new_value = self.stack.pop()?;
        ensure(self.gas_left() > gas::CALL_STIPEND, EVMError::OutOfGas)?; // EIP-1706

        let evm_address = self.message().target.evm;
        let account = self.env.state.get_account(evm_address);
        let original_value = fetch_original_storage(@account, key);
        let current_value = self.env.state.read_state(evm_address, key);

        // GAS
        let mut gas_cost = 0;
        if !self.accessed_storage_keys.contains((evm_address, key)) {
            self.accessed_storage_keys.add((evm_address, key));
            gas_cost += gas::COLD_SLOAD_COST;
        }

        if original_value == current_value && current_value != new_value {
            if original_value == 0 {
                gas_cost += gas::SSTORE_SET
            } else {
                gas_cost += gas::SSTORE_RESET - gas::COLD_SLOAD_COST;
            }
        } else {
            gas_cost += gas::WARM_ACCESS_COST;
        }

        // Gas refunds
        if current_value != new_value {
            if original_value != 0 && current_value != 0 && new_value == 0 {
                // Storage is cleared for the first time in the transaction
                self.gas_refund += gas::REFUND_SSTORE_CLEARS;
            }

            if original_value != 0 && current_value == 0 {
                // Earlier gas refund needs to be reversed
                self.gas_refund -= gas::REFUND_SSTORE_CLEARS;
            }

            if original_value == new_value {
                // Restoring slot to original value (used as transient storage)
                if original_value == 0 {
                    // The access cost is still charged but the SSTORE cost is refunded
                    self.gas_refund += (gas::SSTORE_SET - gas::WARM_ACCESS_COST);
                } else {
                    // Slot was originally non-empty and was updated earlier
                    // cold sload cost and warm access cost are not refunded
                    self
                        .gas_refund +=
                            (gas::SSTORE_RESET - gas::COLD_SLOAD_COST - gas::WARM_ACCESS_COST);
                }
            }
        }

        self.charge_gas(gas_cost)?;

        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

        self.env.state.write_state(:evm_address, :key, value: new_value);
        Result::Ok(())
    }


    /// 0x56 - JUMP operation
    /// The JUMP instruction changes the pc counter.
    /// The new pc target has to be a JUMPDEST opcode.
    /// # Specification: https://www.evm.codes/#56?fork=shanghai
    ///
    ///  Valid jump destinations are defined as follows:
    ///     * The jump destination is less than the length of the code.
    ///     * The jump destination should have the `JUMPDEST` opcode (0x5B).
    ///     * The jump destination shouldn't be part of the data corresponding to
    ///       `PUSH-N` opcodes.
    ///
    /// Note: Jump destinations are 0-indexed.
    fn exec_jump(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::MID)?;

        let index = self.stack.pop_usize()?;
        jump(ref self, index)
    }

    /// 0x57 - JUMPI operation.
    /// Change the pc counter under a provided certain condition.
    /// The new pc target has to be a JUMPDEST opcode.
    /// # Specification: https://www.evm.codes/#57?fork=shanghai
    fn exec_jumpi(ref self: VM) -> Result<(), EVMError> {
        let index = self
            .stack
            .pop_saturating_usize()?; // Saturate because if b is 0, we skip the jump but don't want to fail here.
        let b = self.stack.pop()?;

        self.charge_gas(gas::HIGH)?;

        if b != 0x0 {
            jump(ref self, index)?;
        } else {
            // Return with a PC incremented by one - as JUMP and JUMPi increments
            // are skipped in the main `execute_code` loop
            self.set_pc(self.pc() + 1);
        }

        Result::Ok(())
    }

    /// 0x58 - PC operation
    /// Get the value of the program counter prior to the increment.
    /// # Specification: https://www.evm.codes/#58?fork=shanghai
    fn exec_pc(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let pc = self.pc().into();
        self.stack.push(pc)
    }

    /// 0x59 - MSIZE operation.
    /// Get the value of memory size.
    /// # Specification: https://www.evm.codes/#59?fork=shanghai
    fn exec_msize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let msize: u256 = self.memory.size().into();
        self.stack.push(msize)
    }


    /// 0x5A - GAS operation
    /// Get the amount of available gas, including the corresponding reduction for the cost of this
    /// instruction.
    /// # Specification: https://www.evm.codes/#5a?fork=shanghai
    fn exec_gas(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.gas_left().into())
    }


    /// 0x5b - JUMPDEST operation
    /// Serves as a check that JUMP or JUMPI was executed correctly.
    /// # Specification: https://www.evm.codes/#5b?fork=shanghai
    ///
    /// This doesn't have any affect on execution state, so we don't have
    /// to do anything here. It's a NO-OP.
    fn exec_jumpdest(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::JUMPDEST)?;
        Result::Ok(())
    }

    /// 0x5c - TLOAD operation.
    /// Load a word from the transient storage.
    /// # Specification: https://www.evm.codes/#5c?fork=cancun
    fn exec_tload(ref self: VM) -> Result<(), EVMError> {
        let key = self.stack.pop()?;
        let evm_address = self.message().target.evm;

        self.charge_gas(gas::WARM_ACCESS_COST)?;

        let value = self.env.state.read_transient_storage(evm_address, key);
        self.stack.push(value)
    }

    /// 0x5d - TSTORE operation.
    /// Save a word to the transient storage.
    /// # Specification: https://www.evm.codes/#5d?fork=cancun
    fn exec_tstore(ref self: VM) -> Result<(), EVMError> {
        let key = self.stack.pop()?;
        let value = self.stack.pop()?;

        self.charge_gas(gas::WARM_ACCESS_COST)?;

        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;
        self.env.state.write_transient_storage(self.message().target.evm, key, value);

        return Result::Ok(());
    }

    /// 0x5e - MCOPY operation.
    /// Copy memory from one location to another.
    /// # Specification: https://www.evm.codes/#5e?fork=cancun
    fn exec_mcopy(ref self: VM) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_saturating_usize()?;
        let source_offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        let words_size = bytes_32_words_size(size).into();
        let copy_gas_cost = gas::COPY * words_size;
        let memory_expansion = gas::memory_expansion(
            self.memory.size(), [(max(dest_offset, source_offset), size)].span()
        )?;
        self.memory.ensure_length(memory_expansion.new_size);
        //TODO: handle add overflows
        self.charge_gas(gas::VERYLOW + copy_gas_cost + memory_expansion.expansion_cost)?;

        if size == 0 {
            return Result::Ok(());
        }

        self.memory.copy(size, source_offset, dest_offset);
        Result::Ok(())
    }
}


#[cfg(test)]
mod tests {
    use core::cmp::max;
    use core::num::traits::Bounded;
    use core::result::ResultTrait;
    use crate::errors::EVMError;
    use crate::gas;
    use crate::instructions::MemoryOperationTrait;
    use crate::memory::MemoryTrait;
    use crate::model::Address;
    use crate::model::vm::VMTrait;
    use crate::model::{Account, AccountTrait};
    use crate::stack::StackTrait;
    use crate::state::StateTrait;
    use crate::test_utils::{
        VMBuilderTrait, MemoryTestUtilsTrait, setup_test_environment, uninitialized_account,
        native_token
    };
    use snforge_std::{test_address, start_mock_call};
    use utils::helpers::compute_starknet_address;
    use utils::traits::bytes::U8SpanExTrait;

    #[test]
    fn test_pc_basic() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_pc().expect('exec_pc failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.pop().unwrap() == 0, 'PC should be 0');
    }


    #[test]
    fn test_pc_gets_updated_properly_1() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.set_pc(9000);
        vm.exec_pc().expect('exec_pc failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.pop().unwrap() == 9000, 'updating PC failed');
    }

    // 0x51 - MLOAD

    #[test]
    fn test_exec_mload_should_load_a_value_from_memory() {
        assert_mload(0x1, 0, 0x1, 32);
    }

    #[test]
    fn test_exec_mload_should_load_a_value_from_memory_with_memory_expansion() {
        assert_mload(0x1, 16, 0x100000000000000000000000000000000, 64);
    }

    #[test]
    fn test_exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize() {
        assert_mload(0x1, 684, 0x0, 736);
    }

    fn assert_mload(value: u256, offset: u256, expected_value: u256, expected_memory_size: u32) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.memory.store_with_expansion(value, 0);

        vm.stack.push(offset).expect('push failed');

        // When
        vm.exec_mload().expect('exec_mload failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.pop().unwrap() == expected_value, 'mload failed');
        assert(vm.memory.size() == expected_memory_size, 'memory size error');
    }

    #[test]
    fn test_exec_pop_should_pop_an_item_from_stack() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x01).expect('push failed');
        vm.stack.push(0x02).expect('push failed');

        // When
        let result = vm.exec_pop();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x01, 'stack peek should return 0x01');
    }

    #[test]
    fn test_exec_pop_should_stack_underflow() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        let result = vm.exec_pop();

        // Then
        assert(result.is_err(), 'should return Err ');
        assert!(result.unwrap_err() == EVMError::StackUnderflow, "should return StackUnderflow");
    }

    #[test]
    fn test_exec_mstore_should_store_max_uint256_offset_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        let result = vm.exec_mstore();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
        let stored = vm.memory.load(0);
        assert(stored == Bounded::<u256>::MAX, 'should have stored max_uint256');
    }

    #[test]
    fn test_exec_mstore_should_store_max_uint256_offset_1() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x01).expect('push failed');

        // When
        let result = vm.exec_mstore();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.memory.size() == 64, 'memory should be 64 bytes long');
        let stored = vm.memory.load(1);
        assert(stored == Bounded::<u256>::MAX, 'should have stored max_uint256');
    }

    #[test]
    fn test_exec_mstore8_should_store_uint8_offset_31() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0xAB).expect('push failed');
        vm.stack.push(31).expect('push failed');

        // When
        let result = vm.exec_mstore8();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
        let stored = vm.memory.load(0);
        assert(stored == 0xAB, 'mstore8 failed');
    }

    #[test]
    fn test_exec_mstore8_should_store_uint8_offset_30() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0xAB).expect('push failed');
        vm.stack.push(30).expect('push failed');

        // When
        let result = vm.exec_mstore8();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
        let stored = vm.memory.load(0);
        assert(stored == 0xAB00, 'mstore8 failed');
    }

    #[test]
    fn test_exec_mstore8_should_store_uint8_offset_31_then_uint8_offset_30() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0xAB).expect('push failed');
        vm.stack.push(30).expect('push failed');
        vm.stack.push(0xCD).expect('push failed');
        vm.stack.push(31).expect('push failed');

        // When
        let result1 = vm.exec_mstore8();
        let result2 = vm.exec_mstore8();

        // Then
        assert(result1.is_ok() && result2.is_ok(), 'should have succeeded');
        assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
        let stored = vm.memory.load(0);
        assert(stored == 0xABCD, 'mstore8 failed');
    }

    #[test]
    fn test_exec_mstore8_should_store_last_uint8_offset_31() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x123456789ABCDEF).expect('push failed');
        vm.stack.push(31).expect('push failed');

        // When
        let result = vm.exec_mstore8();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
        let stored = vm.memory.load(0);
        assert(stored == 0xEF, 'mstore8 failed');
    }


    #[test]
    fn test_exec_mstore8_should_store_last_uint8_offset_63() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x123456789ABCDEF).expect('push failed');
        vm.stack.push(63).expect('push failed');

        // When
        let result = vm.exec_mstore8();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.memory.size() == 64, 'memory should be 64 bytes long');
        let stored = vm.memory.load(32);
        assert(stored == 0xEF, 'mstore8 failed');
    }

    #[test]
    fn test_msize_initial() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        let result = vm.exec_msize();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.pop().unwrap() == 0, 'initial memory size should be 0');
    }

    #[test]
    fn test_exec_msize_should_return_size_of_memory() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0x00);

        // When
        let result = vm.exec_msize();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.pop().unwrap() == 32, 'should 32 bytes after MSIZE');
    }

    #[test]
    fn test_exec_jump_valid() {
        // Given
        let bytecode: Span<u8> = [0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let counter = 0x03;
        vm.stack.push(counter).expect('push failed');

        // When
        vm.exec_jump().expect('exec_jump failed');

        // Then
        let pc = vm.pc();
        assert(pc == 0x03, 'PC should be JUMPDEST');
    }


    #[test]
    fn test_exec_jump_invalid() {
        // Given
        let bytecode: Span<u8> = [0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let counter = 0x02;
        vm.stack.push(counter).expect('push failed');

        // When
        let result = vm.exec_jump();

        // Then
        assert(result.is_err(), 'invalid jump dest');
        assert(result.unwrap_err() == EVMError::InvalidJump, 'invalid jump dest');
    }

    #[test]
    fn test_exec_jump_out_of_bounds() {
        // Given
        let bytecode: Span<u8> = [0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let counter = 0xFF;
        vm.stack.push(counter).expect('push failed');

        // When
        let result = vm.exec_jump();

        // Then
        assert(result.is_err(), 'invalid jump dest');
        assert(result.unwrap_err() == EVMError::InvalidJump, 'invalid jump dest');
    }

    // TODO: This is third edge case in which `0x5B` is part of PUSHN instruction and hence
    // not a valid opcode to jump to
    #[test]
    fn test_exec_jump_inside_pushn() {
        // Given
        let bytecode: Span<u8> = [0x60, 0x5B, 0x60, 0x00].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let counter = 0x01;
        vm.stack.push(counter).expect('push failed');

        // When
        let result = vm.exec_jump();

        // Then
        assert(result.is_err(), 'exec_jump should throw error');
        assert(result.unwrap_err() == EVMError::InvalidJump, 'jump dest should be invalid');
    }

    #[test]
    fn test_exec_jumpi_valid_non_zero_1() {
        // Given
        let bytecode: Span<u8> = [0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let b = 0x1;
        vm.stack.push(b).expect('push failed');
        let counter = 0x03;
        vm.stack.push(counter).expect('push failed');

        // When
        vm.exec_jumpi().expect('exec_jumpi failed');

        // Then
        let pc = vm.pc();
        assert(pc == 0x03, 'PC should be JUMPDEST');
    }

    #[test]
    fn test_exec_jumpi_valid_non_zero_2() {
        // Given
        let bytecode: Span<u8> = [0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let b = 0x69;
        vm.stack.push(b).expect('push failed');
        let counter = 0x03;
        vm.stack.push(counter).expect('push failed');

        // When
        vm.exec_jumpi().expect('exec_jumpi failed');

        // Then
        let pc = vm.pc();
        assert(pc == 0x03, 'PC should be JUMPDEST');
    }

    #[test]
    fn test_exec_jumpi_valid_zero() {
        // Given
        let bytecode: Span<u8> = [0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let b = 0x0;
        vm.stack.push(b).expect('push failed');
        let counter = 0x03;
        vm.stack.push(counter).expect('push failed');
        let old_pc = vm.pc();

        // When
        vm.exec_jumpi().expect('exec_jumpi failed');

        // Then
        let pc = vm.pc();
        // If the jump is not taken, the PC should be incremented by 1
        assert_eq!(pc, old_pc + 1);
    }

    #[test]
    fn test_exec_jumpi_invalid_non_zero() {
        // Given
        let bytecode: Span<u8> = [0x60, 0x5B, 0x60, 0x00].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let b = 0x69;
        vm.stack.push(b).expect('push failed');
        let counter = 0x69;
        vm.stack.push(counter).expect('push failed');

        // When
        let result = vm.exec_jumpi();

        // Then
        assert(result.is_err(), 'invalid jump dest');
        assert(result.unwrap_err() == EVMError::InvalidJump, 'invalid jump dest');
    }


    #[test]
    fn test_exec_jumpi_invalid_zero() {
        // Given
        let bytecode: Span<u8> = [0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let b = 0x0;
        vm.stack.push(b).expect('push failed');
        let counter = 0x69;
        vm.stack.push(counter).expect('push failed');
        let old_pc = vm.pc();

        // When
        vm.exec_jumpi().expect('exec_jumpi failed');

        // Then
        let pc = vm.pc();
        // If the jump is not taken, the PC should be incremented by 1
        assert_eq!(pc, old_pc + 1);
    }

    #[test]
    #[should_panic(expected: ('exec_jump should throw error',))]
    fn test_exec_jumpi_inside_pushn() {
        // Given
        let bytecode: Span<u8> = [0x60, 0x5B, 0x60, 0x00].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        let b = 0x00;
        vm.stack.push(b).expect('push failed');
        let counter = 0x01;
        vm.stack.push(counter).expect('push failed');

        // When
        let result = vm.exec_jumpi();

        // Then
        assert(result.is_err(), 'exec_jump should throw error');
        assert(result.unwrap_err() == EVMError::InvalidJump, 'jump dest should be invalid');
    }

    #[test]
    fn test_exec_sload_should_push_value_on_stack() {
        // Given
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let evm_address = vm.message().target.evm;

        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0x02;
        vm.env.state.write_state(evm_address, key, value);
        vm.stack.push(key.into()).expect('push failed');

        // When
        let result = vm.exec_sload();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.pop().unwrap() == value, 'sload failed');
    }

    #[test]
    fn test_exec_sstore_on_account_in_st() {
        // Given
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let test_address = test_address();
        let evm_address = vm.message().target.evm;
        let starknet_address = compute_starknet_address(
            test_address, evm_address, uninitialized_account()
        );
        let bytecode = [0xab, 0xcd, 0xef].span();
        let code_hash = bytecode.compute_keccak256_hash();
        let account = Account {
            address: Address { evm: evm_address, starknet: starknet_address },
            code: bytecode,
            code_hash: code_hash,
            nonce: 1,
            balance: 0,
            selfdestruct: false,
            is_created: false,
        };
        vm.env.state.set_account(account);

        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;

        vm.stack.push(value).expect('push failed');
        vm.stack.push(key).expect('push failed');

        // When
        start_mock_call::<u256>(starknet_address, selector!("storage"), 0);
        let result = vm.exec_sstore();

        // Then
        assert(result.is_ok(), 'exec sstore failed');
        assert(vm.env.state.read_state(evm_address, key) == value, 'wrong value in state');
    }

    #[test]
    fn test_exec_sstore_on_account_undeployed() {
        // Given
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let evm_address = vm.message().target.evm;
        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;

        vm.stack.push(value).expect('push failed');
        vm.stack.push(key).expect('push failed');

        // When
        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        let result = vm.exec_sstore();

        // Then
        assert(result.is_ok(), 'exec sstore failed');
        assert(vm.env.state.read_state(evm_address, key) == value, 'wrong value in state');
    }

    #[test]
    fn test_exec_sstore_on_contract_account_alive() {
        // Given
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let test_address = test_address();
        let evm_address = vm.message().target.evm;
        let starknet_address = compute_starknet_address(
            test_address, evm_address, uninitialized_account()
        );
        let bytecode = [0xab, 0xcd, 0xef].span();
        let code_hash = bytecode.compute_keccak256_hash();
        let account = Account {
            address: Address { evm: evm_address, starknet: starknet_address },
            code: bytecode,
            code_hash: code_hash,
            nonce: 1,
            balance: 0,
            selfdestruct: false,
            is_created: false,
        };
        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;

        vm.stack.push(value).expect('push failed');
        vm.stack.push(key).expect('push failed');

        vm.env.state.set_account(account);
        assert!(vm.env.state.is_account_alive(account.address.evm));

        // When
        start_mock_call::<u256>(account.starknet_address(), selector!("storage"), 0);
        let result = vm.exec_sstore();

        // Then
        assert(result.is_ok(), 'exec sstore failed');
        assert(vm.env.state.read_state(evm_address, key) == value, 'wrong value in state');
    }

    #[test]
    fn test_exec_sstore_should_fail_static_call() {
        // Given
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().with_read_only().build();
        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;
        vm.stack.push(value).expect('push failed');
        vm.stack.push(key).expect('push failed');

        // When
        start_mock_call::<u256>(vm.message().target.starknet, selector!("storage"), 0);
        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        let result = vm.exec_sstore();

        // Then
        assert(result.is_err(), 'should have errored');
        assert(result.unwrap_err() == EVMError::WriteInStaticContext, 'wrong error returned');
    }

    #[test]
    fn test_exec_sstore_should_fail_gas_left_inf_call_stipend_eip_1706() {
        // Given
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().with_gas_left(gas::CALL_STIPEND).build();
        let test_address = test_address();
        let evm_address = vm.message().target.evm;
        let starknet_address = compute_starknet_address(
            test_address, evm_address, uninitialized_account()
        );
        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;
        vm.stack.push(value).expect('push failed');
        vm.stack.push(key).expect('push failed');

        // When
        start_mock_call::<u256>(starknet_address, selector!("storage"), 0);
        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        let result = vm.exec_sstore();

        // Then
        assert(result.is_err(), 'should have errored');
        assert(result.unwrap_err() == EVMError::OutOfGas, 'wrong error returned');
    }


    #[test]
    fn test_gas_should_push_gas_left_to_stack() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_gas().unwrap();

        // Then
        let result = vm.stack.peek().unwrap();
        assert(result == vm.gas_left().into(), 'stack top should be gas_limit');
    }

    #[test]
    fn test_tload_should_load_a_value_from_transient_storage() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;
        vm.env.state.write_transient_storage(vm.message().target.evm, key, value);
        vm.stack.push(key.into()).expect('push failed');

        // When
        let gas_before = vm.gas_left();
        vm.exec_tload().expect('exec_tload failed');
        let gas_after = vm.gas_left();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.pop().unwrap() == value, 'tload failed');
        assert(gas_before - gas_after == gas::WARM_ACCESS_COST, 'gas charged error');
    }

    #[test]
    fn test_tstore_should_fail_staticcall() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_read_only().build();
        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;
        vm.stack.push(value).expect('push failed');
        vm.stack.push(key.into()).expect('push failed');

        // When
        let gas_before = vm.gas_left();
        let result = vm.exec_tstore();
        let gas_after = vm.gas_left();

        // Then
        assert(result.is_err(), 'should have errored');
        assert(result.unwrap_err() == EVMError::WriteInStaticContext, 'wrong error returned');
        assert(gas_before - gas_after == gas::WARM_ACCESS_COST, 'gas charged error');
    }

    #[test]
    fn test_tstore_should_store_a_value_to_transient_storage() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let key: u256 = 0x100000000000000000000000000000001;
        let value: u256 = 0xABDE1E11A5;
        vm.stack.push(value).expect('push failed');
        vm.stack.push(key.into()).expect('push failed');

        // When
        let gas_before = vm.gas_left();
        vm.exec_tstore().expect('exec_tstore failed');
        let gas_after = vm.gas_left();

        // Then
        assert(
            vm.env.state.read_transient_storage(vm.message().target.evm, key) == value,
            'tstore failed'
        );
        assert(gas_before - gas_after == gas::WARM_ACCESS_COST, 'gas charged error');
    }

    #[test]
    fn test_exec_mcopy_should_copy_two_words_at_destination_offset() {
        let values: Array<u32> = array![0xFF, 0xEE];
        assert_mcopy(0x00, 0x80, 0x40, values);
    }

    #[test]
    fn test_exec_mcopy_should_copy_two_words_at_destination_offset_with_overlap() {
        let values: Array<u32> = array![0xFF, 0xEE];
        assert_mcopy(0x00, 0x20, 0x40, values);
    }

    fn assert_mcopy(source_offset: u32, dest_offset: u32, size: u32, values: Array<u32>) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let mut i = 0;
        for element in values
            .span() {
                vm.memory.store_with_expansion((*element).into(), source_offset + 0x20 * i);
                i += 1;
            };
        vm.stack.push(size.into()).expect('push failed');
        vm.stack.push(source_offset.into()).expect('push failed');
        vm.stack.push(dest_offset.into()).expect('push failed');

        let words_size = ((size + 31) / 32).into();
        let copy_gas_cost = gas::COPY * words_size;

        // When
        let expected_gas = gas::VERYLOW
            + gas::memory_expansion(
                vm.memory.size(), [(max(dest_offset, source_offset), size)].span()
            )
                .unwrap()
                .expansion_cost
            + copy_gas_cost;
        let gas_before = vm.gas_left();
        let result = vm.exec_mcopy();
        let gas_after = vm.gas_left();

        // Then
        assert(result.is_ok(), 'should have succeeded');
        assert(vm.stack.is_empty(), 'stack should be empty');
        assert(vm.memory.size() == dest_offset + size, 'memory size error');
        i = 0;
        for element in values
            .span() {
                let stored_word = vm.memory.load(dest_offset + 0x20 * i);
                assert(stored_word == (*element).into(), 'mcopy failed');
                i += 1;
            };
        assert(gas_before - gas_after == expected_gas, 'gas error');
    }
}
