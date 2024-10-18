use core::dict::{Felt252Dict, Felt252DictTrait};
//! Stack implementation.
//! # Example
//! ```
//! use crate::stack::StackTrait;
//!
//! // Create a new stack instance.
//! let mut stack = StackTrait::new();
//! let val_1: u256 = 1.into();
//! let val_2: u256 = 1.into();

//! stack.push(val_1)?;
//! stack.push(val_2)?;

//! let value = stack.pop()?;
//! ```
use core::nullable::{NullableTrait};
use core::num::traits::Bounded;
use core::starknet::EthAddress;
use crate::errors::{ensure, EVMError};

use utils::constants;
use utils::i256::i256;
use utils::traits::{TryIntoResult};


//TODO(optimization): make len `felt252` based to avoid un-necessary checks
#[derive(Destruct, Default)]
pub struct Stack {
    pub items: Felt252Dict<Nullable<u256>>,
    pub len: usize,
}

pub trait StackTrait {
    fn new() -> Stack;
    fn push(ref self: Stack, item: u256) -> Result<(), EVMError>;
    fn pop(ref self: Stack) -> Result<u256, EVMError>;
    fn pop_usize(ref self: Stack) -> Result<usize, EVMError>;
    fn pop_saturating_usize(ref self: Stack) -> Result<usize, EVMError>;
    fn pop_u64(ref self: Stack) -> Result<u64, EVMError>;
    fn pop_saturating_u64(ref self: Stack) -> Result<u64, EVMError>;
    fn pop_u128(ref self: Stack) -> Result<u128, EVMError>;
    fn pop_saturating_u128(ref self: Stack) -> Result<u128, EVMError>;
    fn pop_i256(ref self: Stack) -> Result<i256, EVMError>;
    fn pop_eth_address(ref self: Stack) -> Result<EthAddress, EVMError>;
    fn pop_n(ref self: Stack, n: usize) -> Result<Array<u256>, EVMError>;
    fn peek(ref self: Stack) -> Option<u256>;
    fn peek_at(ref self: Stack, index: usize) -> Result<u256, EVMError>;
    fn swap_i(ref self: Stack, index: usize) -> Result<(), EVMError>;
    fn len(self: @Stack) -> usize;
    fn is_empty(self: @Stack) -> bool;
}

impl StackImpl of StackTrait {
    #[inline(always)]
    fn new() -> Stack {
        Default::default()
    }

    /// Pushes a new bytes32 word onto the stack.
    ///
    /// The item is stored at the current length of the stack.
    ///
    /// # Errors
    ///
    /// If the stack is full, returns with a StackOverflow error.
    #[inline(always)]
    fn push(ref self: Stack, item: u256) -> Result<(), EVMError> {
        let length = self.len();
        // we can store at most 1024 256-bits words
        ensure(length != constants::STACK_MAX_DEPTH, EVMError::StackOverflow)?;

        self.items.insert(length.into(), NullableTrait::new(item));
        self.len += 1;
        Result::Ok(())
    }

    /// Pops the top item off the stack.
    ///
    /// # Errors
    ///
    /// If the stack is empty, returns with a StackUnderflow error.
    #[inline(always)]
    fn pop(ref self: Stack) -> Result<u256, EVMError> {
        ensure(self.len() != 0, EVMError::StackUnderflow)?;

        self.len -= 1;
        let item = self.items.get(self.len().into());
        Result::Ok(item.deref())
    }

    /// Calls `Stack::pop` and tries to convert it to usize
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    ///     - Type conversion failed
    #[inline(always)]
    fn pop_usize(ref self: Stack) -> Result<usize, EVMError> {
        let item: u256 = self.pop()?;
        let item: usize = item.try_into_result()?;
        Result::Ok(item)
    }

    /// Calls `Stack::pop` and saturates the result to usize
    #[inline(always)]
    fn pop_saturating_usize(ref self: Stack) -> Result<usize, EVMError> {
        let item: u256 = self.pop()?;
        if item.high != 0 {
            return Result::Ok(Bounded::<usize>::MAX);
        };
        match item.low.try_into() {
            Option::Some(value) => Result::Ok(value),
            Option::None => Result::Ok(Bounded::<usize>::MAX),
        }
    }

    /// Calls `Stack::pop` and tries to convert it to u64
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    ///     - Type conversion failed
    #[inline(always)]
    fn pop_u64(ref self: Stack) -> Result<u64, EVMError> {
        let item: u256 = self.pop()?;
        let item: u64 = item.try_into_result()?;
        Result::Ok(item)
    }

    /// Calls `Stack::pop` and saturates the result to u64
    #[inline(always)]
    fn pop_saturating_u64(ref self: Stack) -> Result<u64, EVMError> {
        let item: u256 = self.pop()?;
        if item.high != 0 {
            return Result::Ok(Bounded::<u64>::MAX);
        };
        match item.low.try_into() {
            Option::None => Result::Ok(Bounded::<u64>::MAX),
            Option::Some(value) => Result::Ok(value),
        }
    }

    /// Calls `Stack::pop` and convert it to i256
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    #[inline(always)]
    fn pop_i256(ref self: Stack) -> Result<i256, EVMError> {
        let item: u256 = self.pop()?;
        let item: i256 = item.into();
        Result::Ok(item)
    }


    /// Calls `Stack::pop` and tries to convert it to u128
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    ///     - Type conversion failed
    #[inline(always)]
    fn pop_u128(ref self: Stack) -> Result<u128, EVMError> {
        let item: u256 = self.pop()?;
        let item: u128 = item.try_into_result()?;
        Result::Ok(item)
    }

    /// Calls `Stack::pop` and saturates the result to u128
    ///
    #[inline(always)]
    fn pop_saturating_u128(ref self: Stack) -> Result<u128, EVMError> {
        let item: u256 = self.pop()?;
        if item.high != 0 {
            return Result::Ok(Bounded::<u128>::MAX);
        };
        Result::Ok(item.low)
    }

    /// Calls `Stack::pop` and converts it to an EthAddress
    /// If the value is bigger than an EthAddress, it will be truncated to keep the lower 160 bits.
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    #[inline(always)]
    fn pop_eth_address(ref self: Stack) -> Result<EthAddress, EVMError> {
        let item: u256 = self.pop()?;
        let item: EthAddress = item.into();
        Result::Ok(item)
    }

    /// Pops N elements from the stack.
    ///
    /// # Errors
    ///
    /// If the stack length is less than than N, returns with a StackUnderflow error.
    fn pop_n(ref self: Stack, mut n: usize) -> Result<Array<u256>, EVMError> {
        ensure(!(n > self.len()), EVMError::StackUnderflow)?;
        let mut popped_items = ArrayTrait::<u256>::new();
        let mut err = Result::Ok(array![]);
        for _ in 0..n {
            let popped_item = self.pop();
            match popped_item {
                Result::Ok(item) => popped_items.append(item),
                Result::Err(pop_error) => { err = Result::Err(pop_error); break;},
            };
        };
        if err.is_err() {
            return err;
        }
        Result::Ok(popped_items)
    }

    /// Peeks at the top item on the stack.
    ///
    /// # Errors
    ///
    /// If the stack is empty, returns None.
    #[inline(always)]
    fn peek(ref self: Stack) -> Option<u256> {
        if self.len() == 0 {
            Option::None(())
        } else {
            let last_index = self.len() - 1;
            let item = self.items.get(last_index.into());
            Option::Some(item.deref())
        }
    }

    /// Peeks at the item at the given index on the stack.
    /// index is 0-based, where 0 is the top of the stack (most recently pushed item).
    ///
    /// # Errors
    ///
    /// If the index is greater than the stack length, returns with a StackUnderflow error.
    #[inline(always)]
    fn peek_at(ref self: Stack, index: usize) -> Result<u256, EVMError> {
        ensure(index < self.len(), EVMError::StackUnderflow)?;

        let position = self.len() - 1 - index;
        let item = self.items.get(position.into());

        Result::Ok(item.deref())
    }

    /// Swaps the item at the given index with the item on top of the stack.
    /// index is 0-based, where 0 would mean no swap (top item swapped with itself).
    #[inline(always)]
    fn swap_i(ref self: Stack, index: usize) -> Result<(), EVMError> {
        ensure(index < self.len(), EVMError::StackUnderflow)?;

        let position_0: felt252 = self.len().into() - 1;
        let position_item: felt252 = position_0 - index.into();
        let top_item = self.items.get(position_0);
        let swapped_item = self.items.get(position_item);
        self.items.insert(position_0, swapped_item.into());
        self.items.insert(position_item, top_item.into());
        Result::Ok(())
    }

    /// Returns the length of the stack.
    #[inline(always)]
    fn len(self: @Stack) -> usize {
        *self.len
    }

    /// Returns true if the stack is empty.
    #[inline(always)]
    fn is_empty(self: @Stack) -> bool {
        self.len() == 0
    }
}

#[cfg(test)]
mod tests {
    // Core lib imports

    // Internal imports
    use crate::stack::StackTrait;
    use utils::constants;

    #[test]
    fn test_stack_new_should_return_empty_stack() {
        // When
        let mut stack = StackTrait::new();

        // Then
        assert_eq!(stack.len(), 0);
    }

    #[test]
    fn test_empty_should_return_if_stack_is_empty() {
        // Given
        let mut stack = StackTrait::new();

        // Then
        assert!(stack.is_empty());

        // When
        stack.push(1).unwrap();
        // Then
        assert!(!stack.is_empty());
    }

    #[test]
    fn test_len_should_return_the_length_of_the_stack() {
        // Given
        let mut stack = StackTrait::new();

        // Then
        assert_eq!(stack.len(), 0);

        // When
        stack.push(1).unwrap();
        // Then
        assert_eq!(stack.len(), 1);
    }

    mod push {
        use crate::errors::{EVMError};
        use super::StackTrait;

        use super::constants;

        #[test]
        fn test_should_add_an_element_to_the_stack() {
            // Given
            let mut stack = StackTrait::new();

            // When
            stack.push(1).unwrap();

            // Then
            let res = stack.peek().unwrap();

            assert_eq!(stack.is_empty(), false);
            assert_eq!(stack.len(), 1);
            assert_eq!(res, 1);
        }

        #[test]
        fn test_should_fail_when_overflow() {
            // Given
            let mut stack = StackTrait::new();

            // When
            for _ in 0..constants::STACK_MAX_DEPTH {
                stack.push(1).unwrap();
            };

            // Then
            let res = stack.push(1);
            assert_eq!(stack.len(), constants::STACK_MAX_DEPTH);
            assert!(res.is_err());
            assert_eq!(res.unwrap_err(), EVMError::StackOverflow);
        }
    }

    mod pop {
        use core::num::traits::Bounded;
        use crate::errors::EVMError;
        use super::StackTrait;
        use utils::traits::StorageBaseAddressPartialEq;

        #[test]
        fn test_should_pop_an_element_from_the_stack() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1).unwrap();
            stack.push(2).unwrap();
            stack.push(3).unwrap();

            // When
            let last_item = stack.pop().unwrap();

            // Then
            assert_eq!(last_item, 3);
            assert_eq!(stack.len(), 2);
        }


        #[test]
        fn test_should_pop_N_elements_from_the_stack() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1).unwrap();
            stack.push(2).unwrap();
            stack.push(3).unwrap();

            // When
            let elements = stack.pop_n(3).unwrap();

            // Then
            assert_eq!(stack.len(), 0);
            assert_eq!(elements.len(), 3);
            assert_eq!(elements.span(), [3, 2, 1].span())
        }


        #[test]
        fn test_pop_return_err_when_stack_underflow() {
            // Given
            let mut stack = StackTrait::new();

            // When & Then
            let result = stack.pop();
            assert(result.is_err(), 'should return Err ');
            assert!(
                result.unwrap_err() == EVMError::StackUnderflow, "should return StackUnderflow"
            );
        }

        #[test]
        fn test_pop_n_should_return_err_when_stack_underflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1).unwrap();

            // When & Then
            let result = stack.pop_n(2);
            assert(result.is_err(), 'should return Error');
            assert!(
                result.unwrap_err() == EVMError::StackUnderflow, "should return StackUnderflow"
            );
        }

        #[test]
        fn test_pop_saturating_usize_should_return_max_when_overflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(Bounded::<u64>::MAX.into()).unwrap();

            // When
            let result = stack.pop_saturating_usize();
            assert!(result.is_ok());
            assert_eq!(result.unwrap(), Bounded::<usize>::MAX);
        }

        #[test]
        fn test_pop_saturating_usize_should_return_value_when_no_overflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1234567890).unwrap();

            // When
            let result = stack.pop_saturating_usize();
            assert!(result.is_ok());
            assert_eq!(result.unwrap(), 1234567890);
        }


        #[test]
        fn test_pop_saturating_u64_should_return_max_when_overflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(Bounded::<u256>::MAX).unwrap();

            // When
            let result = stack.pop_saturating_u64();
            assert!(result.is_ok());
            assert_eq!(result.unwrap(), Bounded::<u64>::MAX);
        }

        #[test]
        fn test_pop_saturating_u64_should_return_value_when_no_overflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1234567890).unwrap();

            // When
            let result = stack.pop_saturating_u64();

            // Then
            assert!(result.is_ok());
            assert_eq!(result.unwrap(), 1234567890);
        }


        #[test]
        fn test_pop_saturating_u128_should_return_max_when_overflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(Bounded::<u256>::MAX).unwrap();

            // When
            let result = stack.pop_saturating_u128();

            // Then
            assert!(result.is_ok());
            assert_eq!(result.unwrap(), Bounded::<u128>::MAX);
        }

        #[test]
        fn test_pop_saturating_u128_should_return_value_when_no_overflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1234567890).unwrap();

            // When
            let result = stack.pop_saturating_u128();

            // Then
            assert!(result.is_ok());
            assert_eq!(result.unwrap(), 1234567890);
        }
    }

    mod peek {
        use crate::errors::{EVMError};
        use super::StackTrait;

        #[test]
        fn test_should_return_last_item() {
            // Given
            let mut stack = StackTrait::new();

            // When
            stack.push(1).unwrap();
            stack.push(2).unwrap();

            // Then
            let last_item = stack.peek().unwrap();
            assert_eq!(last_item, 2);
        }


        #[test]
        fn test_should_return_stack_at_given_index_when_value_is_0() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1).unwrap();
            stack.push(2).unwrap();
            stack.push(3).unwrap();

            // When
            let result = stack.peek_at(0).unwrap();

            // Then
            assert_eq!(result, 3);
        }

        #[test]
        fn test_should_return_stack_at_given_index_when_value_is_1() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1).unwrap();
            stack.push(2).unwrap();
            stack.push(3).unwrap();

            // When
            let result = stack.peek_at(1).unwrap();

            // Then
            assert_eq!(result, 2);
        }

        #[test]
        fn test_should_return_err_when_underflow() {
            // Given
            let mut stack = StackTrait::new();

            // When & Then
            let result = stack.peek_at(1);

            assert(result.is_err(), 'should return an EVMError');
            assert!(
                result.unwrap_err() == EVMError::StackUnderflow, "should return StackUnderflow"
            );
        }
    }

    mod swap {
        use crate::errors::{EVMError};
        use super::StackTrait;

        #[test]
        fn test_should_swap_2_stack_items() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1).unwrap();
            stack.push(2).unwrap();
            stack.push(3).unwrap();
            stack.push(4).unwrap();
            let index3 = stack.peek_at(3).unwrap();
            assert_eq!(index3, 1);
            let index2 = stack.peek_at(2).unwrap();
            assert_eq!(index2, 2);
            let index1 = stack.peek_at(1).unwrap();
            assert_eq!(index1, 3);
            let index0 = stack.peek_at(0).unwrap();
            assert_eq!(index0, 4);

            // When
            stack.swap_i(2).expect('swap failed');

            // Then
            let index3 = stack.peek_at(3).unwrap();
            assert_eq!(index3, 1);
            let index2 = stack.peek_at(2).unwrap();
            assert_eq!(index2, 4);
            let index1 = stack.peek_at(1).unwrap();
            assert_eq!(index1, 3);
            let index0 = stack.peek_at(0).unwrap();
            assert_eq!(index0, 2);
        }

        #[test]
        fn test_should_return_err_when_index_1_is_underflow() {
            // Given
            let mut stack = StackTrait::new();

            // When & Then
            let result = stack.swap_i(1);

            assert!(result.is_err());
            assert_eq!(result.unwrap_err(), EVMError::StackUnderflow);
        }

        #[test]
        fn test_should_return_err_when_index_2_is_underflow() {
            // Given
            let mut stack = StackTrait::new();
            stack.push(1).unwrap();

            // When & Then
            let result = stack.swap_i(2);

            assert!(result.is_err());
            assert_eq!(result.unwrap_err(), EVMError::StackUnderflow);
        }
    }
}

#[cfg(feature: 'pytest')]
mod pytests {
    //! Pytests are tests that are run with the scarb-pytest framework.
    //! This framework allows for testing based on various inputs provided by a third-party test
    //! runner such as pytest or cargo test.
    use core::fmt::{Formatter};
    use crate::errors::{EVMErrorTrait};
    use utils::pytests::json::{JsonMut, Json};
    use utils::pytests::from_array::FromArray;
    use crate::stack::{Stack, StackTrait};

    impl StackJSON of JsonMut<Stack> {
        fn to_json(ref self: Stack) -> ByteArray {
            let mut json: ByteArray = "";
            let mut formatter = Formatter { buffer: json };
            write!(formatter, "[").unwrap();
            for i in 0
                ..self
                    .len() {
                        let item = self.items.get(i.into()).deref();
                        write!(formatter, "{}", item).unwrap();
                        if i != self.len() - 1 {
                            write!(formatter, ", ").unwrap();
                        }
                    };
            write!(formatter, "]").unwrap();
            formatter.buffer
        }
    }

    impl StackFromArray of FromArray<u256> {
        type Output = Stack;
        fn from_array(array: Span<u256>) -> Self::Output {
            let mut stack = StackTrait::new();
            for item in array {
                stack.push(*item).expect('Stack FromArray failed');
            };
            stack
        }
    }

    fn test__stack_push(values: Span<u256>) -> ByteArray {
        let mut stack = StackTrait::new();
        let mut err = Result::Ok(());
        for value in values {
            match stack.push(*value) {
                Result::Ok(()) => (),
                Result::Err(evm_error) => {
                    err = Result::Err(evm_error);
                    break;
                },
            };
        };
        if err.is_err() {
            core::panic_with_felt252(err.unwrap_err().to_string());
        };
        stack.to_json()
    }

    fn test__stack_pop(stack: Span<u256>) -> ByteArray {
        let mut stack = StackFromArray::from_array(stack);
        let mut err = Result::Ok(());
        let value = match stack.pop() {
            Result::Ok(value) => value,
            Result::Err(evm_error) => { err = Result::Err(evm_error); 0},
        };
        if err.is_err() {
            core::panic_with_felt252(err.unwrap_err().to_string());
        };
        let mut output: (Stack, u256) = (stack, value);
        output.to_json()
    }

    fn test__stack_pop_n(stack: Span<u256>, n: usize) -> ByteArray {
        let mut stack = StackFromArray::from_array(stack);
        let mut err = Result::Ok(());
        let values = match stack.pop_n(n) {
            Result::Ok(values) => values,
            Result::Err(evm_error) => { err = Result::Err(evm_error); array![]},
        };
        if err.is_err() {
            core::panic_with_felt252(err.unwrap_err().to_string());
        };
        let mut output: (Stack, Span<u256>) = (stack, values.span());
        output.to_json()
    }

    fn test__stack_peek(stack: Span<u256>, index: usize) -> ByteArray {
        let mut stack = StackFromArray::from_array(stack);
        let mut err = Result::Ok(());
        let value = match stack.peek_at(index) {
            Result::Ok(value) => value,
            Result::Err(evm_error) => { err = Result::Err(evm_error); 0},
        };
        if err.is_err() {
            core::panic_with_felt252(err.unwrap_err().to_string());
        };

        let mut output: (Stack, u256) = (stack, value);
        output.to_json()
    }

    fn test__stack_swap(stack: Span<u256>, index: usize) -> ByteArray {
        let mut stack = StackFromArray::from_array(stack);
        let mut err = Result::Ok(());
        match stack.swap_i(index) {
            Result::Ok(()) => (),
            Result::Err(evm_error) => { err = Result::Err(evm_error); },
        };
        if err.is_err() {
            core::panic_with_felt252(err.unwrap_err().to_string());
        };
        stack.to_json()
    }

    fn test__stack_new() -> ByteArray {
        let mut stack: Stack = Default::default();
        stack.to_json()
    }
}
