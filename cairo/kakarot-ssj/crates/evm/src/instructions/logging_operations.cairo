//! Logging Operations.

use core::num::traits::CheckedAdd;
use crate::errors::{EVMError, ensure};
use crate::gas;
use crate::memory::MemoryTrait;
use crate::model::Event;
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;
use crate::state::StateTrait;


#[generate_trait]
pub impl LoggingOperations of LoggingOperationsTrait {
    /// 0xA0 - LOG0 operation
    /// Append log record with no topic.
    /// # Specification: https://www.evm.codes/#a0?fork=shanghai
    fn exec_log0(ref self: VM) -> Result<(), EVMError> {
        exec_log_i(ref self, 0)
    }

    /// 0xA1 - LOG1
    /// Append log record with one topic.
    /// # Specification: https://www.evm.codes/#a1?fork=shanghai
    fn exec_log1(ref self: VM) -> Result<(), EVMError> {
        exec_log_i(ref self, 1)
    }

    /// 0xA2 - LOG2
    /// Append log record with two topics.
    /// # Specification: https://www.evm.codes/#a2?fork=shanghai
    fn exec_log2(ref self: VM) -> Result<(), EVMError> {
        exec_log_i(ref self, 2)
    }

    /// 0xA3 - LOG3
    /// Append log record with three topics.
    /// # Specification: https://www.evm.codes/#a3?fork=shanghai
    fn exec_log3(ref self: VM) -> Result<(), EVMError> {
        exec_log_i(ref self, 3)
    }

    /// 0xA4 - LOG4
    /// Append log record with four topics.
    /// # Specification: https://www.evm.codes/#a4?fork=shanghai
    fn exec_log4(ref self: VM) -> Result<(), EVMError> {
        exec_log_i(ref self, 4)
    }
}


/// Store a new event in the dynamic context using topics
/// popped from the stack and data from the memory.
///
/// # Arguments
///
/// * `self` - The context to which the event will be added
/// * `topics_len` - The amount of topics to pop from the stack
fn exec_log_i(ref self: VM, topics_len: u8) -> Result<(), EVMError> {
    // Revert if the transaction is in a read only context
    ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

    // TODO(optimization): check benefits of n `pop` instead of `pop_n`
    let offset = self.stack.pop_saturating_usize()?;
    let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.
    let topics: Array<u256> = self.stack.pop_n(topics_len.into())?;

    let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, size)].span())?;
    self.memory.ensure_length(memory_expansion.new_size);

    // TODO: avoid addition overflows here. We should use checked arithmetic.
    let total_cost = gas::LOG
        .checked_add(topics_len.into() * gas::LOGTOPIC)
        .ok_or(EVMError::OutOfGas)?
        .checked_add(size.into() * gas::LOGDATA)
        .ok_or(EVMError::OutOfGas)?
        .checked_add(memory_expansion.expansion_cost)
        .ok_or(EVMError::OutOfGas)?;
    self.charge_gas(total_cost)?;

    let mut data: Array<u8> = Default::default();
    self.memory.load_n(size, ref data, offset);

    let event: Event = Event { keys: topics, data };
    self.env.state.add_event(event);

    Result::Ok(())
}

#[cfg(test)]
mod tests {
    use core::num::traits::Bounded;
    use core::result::ResultTrait;
    use crate::errors::{EVMError, TYPE_CONVERSION_ERROR};
    use crate::instructions::LoggingOperationsTrait;
    use crate::stack::StackTrait;
    use crate::test_utils::{VMBuilderTrait, MemoryTestUtilsTrait};
    use utils::helpers::u256_to_bytes_array;

    #[test]
    fn test_exec_log0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);

        vm.stack.push(0x1F).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        let result = vm.exec_log0();

        // Then
        assert!(result.is_ok());
        assert_eq!(vm.stack.len(), 0);

        let mut events = vm.env.state.events;
        assert_eq!(events.len(), 1);

        let event = events.pop_front().unwrap();
        assert_eq!(event.keys.len(), 0);

        assert_eq!(event.data.len(), 31);
        let data_expected = u256_to_bytes_array(Bounded::<u256>::MAX).span().slice(0, 31);
        assert_eq!(event.data.span(), data_expected);
    }

    #[test]
    fn test_exec_log1() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);

        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x20).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        let result = vm.exec_log1();

        // Then
        assert!(result.is_ok());
        assert_eq!(vm.stack.len(), 0);

        let mut events = vm.env.state.events;
        assert_eq!(events.len(), 1);

        let event = events.pop_front().unwrap();
        assert_eq!(event.keys.len(), 1);
        assert_eq!(event.keys.span(), [0x0123456789ABCDEF].span());

        assert_eq!(event.data.len(), 32);
        let data_expected = u256_to_bytes_array(Bounded::<u256>::MAX).span().slice(0, 32);
        assert_eq!(event.data.span(), data_expected);
    }

    #[test]
    fn test_exec_log2() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);

        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x05).expect('push failed');
        vm.stack.push(0x05).expect('push failed');

        // When
        let result = vm.exec_log2();

        // Then
        assert!(result.is_ok());
        assert_eq!(vm.stack.len(), 0);

        let mut events = vm.env.state.events;
        assert_eq!(events.len(), 1);

        let event = events.pop_front().unwrap();
        assert_eq!(event.keys.len(), 2);
        assert_eq!(event.keys.span(), [0x0123456789ABCDEF, Bounded::<u256>::MAX].span());

        assert_eq!(event.data.len(), 5);
        let data_expected = u256_to_bytes_array(Bounded::<u256>::MAX).span().slice(0, 5);
        assert_eq!(event.data.span(), data_expected);
    }

    #[test]
    fn test_exec_log3() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);
        vm
            .memory
            .store_with_expansion(
                0x0123456789ABCDEF000000000000000000000000000000000000000000000000, 0x20
            );

        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x28).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        let result = vm.exec_log3();

        // Then
        assert!(result.is_ok());
        assert_eq!(vm.stack.len(), 0);

        let mut events = vm.env.state.events;
        assert_eq!(events.len(), 1);

        let event = events.pop_front().unwrap();
        assert_eq!(event.keys.span(), [0x0123456789ABCDEF, Bounded::<u256>::MAX, 0x00].span());

        assert_eq!(event.data.len(), 40);
        let data_expected = u256_to_bytes_array(Bounded::<u256>::MAX).span();
        assert_eq!(event.data.span().slice(0, 32), data_expected);
        let data_expected = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF].span();
        assert_eq!(event.data.span().slice(32, 8), data_expected);
    }

    #[test]
    fn test_exec_log4() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);
        vm
            .memory
            .store_with_expansion(
                0x0123456789ABCDEF000000000000000000000000000000000000000000000000, 0x20
            );

        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x0A).expect('push failed');
        vm.stack.push(0x20).expect('push failed');

        // When
        let result = vm.exec_log4();

        // Then
        assert!(result.is_ok());
        assert_eq!(vm.stack.len(), 0);

        let mut events = vm.env.state.events;
        assert_eq!(events.len(), 1);

        let event = events.pop_front().unwrap();
        assert_eq!(
            event.keys.span(),
            [0x0123456789ABCDEF, Bounded::<u256>::MAX, 0x00, Bounded::<u256>::MAX].span()
        );

        assert_eq!(event.data.len(), 10);
        let data_expected = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x00, 0x00].span();
        assert_eq!(event.data.span(), data_expected);
    }

    #[test]
    fn test_exec_log1_read_only_context() {
        // Given
        let mut vm = VMBuilderTrait::new().with_read_only().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);

        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x20).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        let result = vm.exec_log1();

        // Then
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), EVMError::WriteInStaticContext);
    }

    #[test]
    fn test_exec_log1_size_0_offset_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);

        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        let result = vm.exec_log1();

        // Then
        assert!(result.is_ok());
        assert_eq!(vm.stack.len(), 0);

        let mut events = vm.env.state.events;
        assert_eq!(events.len(), 1);

        let event = events.pop_front().unwrap();
        assert_eq!(event.keys.span(), [0x0123456789ABCDEF].span());

        assert_eq!(event.data.len(), 0);
    }

    #[test]
    fn test_exec_log1_size_too_big() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);

        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        let result = vm.exec_log1();

        // Then
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    #[test]
    fn test_exec_log1_offset_too_big() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);

        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x20).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');

        // When
        let result = vm.exec_log1();

        // Then
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), EVMError::MemoryLimitOOG);
    }

    #[test]
    fn test_exec_log_multiple_events() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.memory.store_with_expansion(Bounded::<u256>::MAX, 0);
        vm
            .memory
            .store_with_expansion(
                0x0123456789ABCDEF000000000000000000000000000000000000000000000000, 0x20
            );

        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x0A).expect('push failed');
        vm.stack.push(0x20).expect('push failed');
        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).expect('push failed');
        vm.stack.push(0x0123456789ABCDEF).expect('push failed');
        vm.stack.push(0x28).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        vm.exec_log3().expect('exec_log3 failed');
        vm.exec_log4().expect('exec_log4 failed');

        // Then
        assert!(vm.stack.is_empty());

        let mut events = vm.env.state.events;
        assert_eq!(events.len(), 2);

        let event1 = events.pop_front().unwrap();
        assert_eq!(event1.keys.span(), [0x0123456789ABCDEF, Bounded::<u256>::MAX, 0x00].span());

        assert_eq!(event1.data.len(), 40);
        let data_expected = u256_to_bytes_array(Bounded::<u256>::MAX).span();
        assert_eq!(event1.data.span().slice(0, 32), data_expected);
        let data_expected = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF].span();
        assert_eq!(event1.data.span().slice(32, 8), data_expected);

        let event2 = events.pop_front().unwrap();
        assert_eq!(
            event2.keys.span(),
            [0x0123456789ABCDEF, Bounded::<u256>::MAX, 0x00, Bounded::<u256>::MAX].span()
        );

        assert_eq!(event2.data.len(), 10);
        let data_expected = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x00, 0x00].span();
        assert_eq!(event2.data.span(), data_expected);
    }
}
