use alexandria_data_structures::vec::VecTrait;
use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use core::num::traits::Zero;
use crate::math::Exponentiation;
use crate::traits::bytes::{ToBytes};


#[derive(Drop, Debug, PartialEq)]
pub enum Felt252VecTraitErrors {
    IndexOutOfBound,
    Overflow,
    LengthIsNotSame,
    SizeLessThanCurrentLength
}

#[generate_trait]
pub impl Felt252VecTraitImpl<
    T,
    +Drop<T>,
    +Copy<T>,
    +Felt252DictValue<T>,
    +Zero<T>,
    +Add<T>,
    +Sub<T>,
    +Div<T>,
    +Mul<T>,
    +Exponentiation<T>,
    +ToBytes<T>,
    +PartialOrd<T>,
    +Into<u8, T>,
    +PartialEq<T>,
> of Felt252VecTrait<T> {
    /// Returns Felt252Vec<T> as a Span<8>, the returned Span is in big endian format
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// # Returns
    /// * A Span<u8> representing bytes conversion of `self` in big endian format
    fn to_be_bytes(ref self: Felt252Vec<T>) -> Span<u8> {
        let mut res: Array<u8> = array![];
        self.remove_trailing_zeroes();

        let mut i = self.len();

        while i != 0 {
            i -= 1;
            res.append_span(self[i].to_be_bytes_padded());
        };

        res.span()
    }

    /// Returns Felt252Vec<T> as a Span<8>, the returned Span is in little endian format
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// # Returns
    /// * A Span<u8> representing bytes conversion of `self` in little endian format
    fn to_le_bytes(ref self: Felt252Vec<T>) -> Span<u8> {
        let mut res: Array<u8> = array![];

        for i in 0
            ..self
                .len() {
                    if self[i] == Zero::zero() {
                        res.append(Zero::zero());
                    } else {
                        res.append_span(self[i].to_le_bytes());
                    }
                };

        res.span()
    }

    /// Expands a Felt252Vec to a new length by appending zeroes
    ///
    /// This function will mutate the Felt252Vec in-place and will expand its length,
    /// since the default value for Felt252Dict item is 0, all new elements will be set to 0.
    /// If the new length is less than the current length, it will return an error.
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `new_length` the new length of the Felt252Vec
    ///
    /// # Returns
    /// * Result::<(), Felt252VecTraitErrors>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::SizeLessThanCurrentLength if the new length is less than the
    /// current length
    fn expand(ref self: Felt252Vec<T>, new_length: usize) -> Result<(), Felt252VecTraitErrors> {
        if (new_length < self.len) {
            return Result::Err(Felt252VecTraitErrors::SizeLessThanCurrentLength);
        };

        self.len = new_length;

        Result::Ok(())
    }

    /// Sets all elements of the Felt252Vec to zero, mutates the Felt252Vec in-place
    ///
    /// # Arguments
    /// self a ref Felt252Vec<T>
    fn reset(ref self: Felt252Vec<T>) {
        let mut new_vec: Felt252Vec<T> = Default::default();
        new_vec.len = self.len;
        self = new_vec;
    }

    /// Returns the leading zeroes of a Felt252Vec<T>
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    ///
    /// # Returns
    /// * The number of leading zeroes in `self`.
    fn count_leading_zeroes(ref self: Felt252Vec<T>) -> usize {
        let mut i = 0;
        while i != self.len() && self[i] == Zero::zero() {
            i += 1;
        };

        i
    }

    /// Resizes the Felt252Vec<T> in-place so that len is equal to new_len.
    ///
    /// This function will mutate the Felt252Vec in-place and will resize its length to the new
    /// length.
    /// If new_len is greater than len, the Vec is extended by the difference, with each additional
    /// slot filled with 0. If new_len is less than len, the Vec is simply truncated from the right.
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `new_len` the new length of the Felt252Vec
    fn resize(ref self: Felt252Vec<T>, new_len: usize) {
        self.len = new_len;
    }


    /// Copies the elements from a Span<u8> into the Felt252Vec<T> in little endian format, in case
    /// of overflow or index being out of bounds, an error is returned
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `index` the index at `self` to start copying from
    /// * `slice` a Span<u8>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::IndexOutOfBound if the index is out of bounds
    /// * Felt252VecTraitErrors::Overflow if the Span is too big to fit in the Felt252Vec
    fn copy_from_bytes_le(
        ref self: Felt252Vec<T>, index: usize, mut slice: Span<u8>
    ) -> Result<(), Felt252VecTraitErrors> {
        if (index >= self.len) {
            return Result::Err(Felt252VecTraitErrors::IndexOutOfBound);
        }

        if ((slice.len() + index) > self.len()) {
            return Result::Err(Felt252VecTraitErrors::Overflow);
        }

        let mut i = index;
        for val in slice {
            // safe unwrap, as in case of none, we will never reach this branch
            self.set(i, (*val).into());
            i += 1;
        };

        Result::Ok(())
    }

    /// Copies the elements from a Felt252Vec<T> into the Felt252Vec<T> in little endian format, If
    /// length of both Felt252Vecs are not same, it will return an error
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `vec` a ref Felt252Vec<T>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::LengthIsNotSame if the length of both Felt252Vecs are not same
    fn copy_from_vec_le(
        ref self: Felt252Vec<T>, ref vec: Felt252Vec<T>
    ) -> Result<(), Felt252VecTraitErrors> {
        if (vec.len() != self.len) {
            return Result::Err(Felt252VecTraitErrors::LengthIsNotSame);
        }

        self = vec.duplicate();

        Result::Ok(())
    }

    /// Insert elements of Felt252Vec into another Felt252Vec at a given index, in case of overflow
    /// or index being out of bounds, an error is returned
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `idx` the index at `self` to start inserting from
    /// * `vec` a ref Felt252Vec<T>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::IndexOutOfBound if the index is out of bounds
    /// * Felt252VecTraitErrors::Overflow if the Felt252Vec is too big to fit in the Felt252Vec
    fn insert_vec(
        ref self: Felt252Vec<T>, idx: usize, ref vec: Felt252Vec<T>
    ) -> Result<(), Felt252VecTraitErrors> {
        if idx >= self.len() {
            return Result::Err(Felt252VecTraitErrors::IndexOutOfBound);
        }

        if (idx + vec.len > self.len) {
            return Result::Err(Felt252VecTraitErrors::Overflow);
        }

        let stop = idx + vec.len();
        for i in idx..stop {
            self.set(i, vec[i - idx]);
        };

        Result::Ok(())
    }


    /// Removes trailing zeroes from a Felt252Vec<T>
    ///
    /// # Arguments
    /// * `input` a ref Felt252Vec<T>
    fn remove_trailing_zeroes(ref self: Felt252Vec<T>) {
        let mut new_len = self.len;
        while (new_len != 0) && (self[new_len - 1] == Zero::zero()) {
            new_len -= 1;
        };

        self.len = new_len;
    }

    /// Pops an element out of the vector, returns Option::None if the vector is empty
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// # Returns
    ///
    /// * Option::Some(T), returns the last element or Option::None if the vector is empty
    fn pop(ref self: Felt252Vec<T>) -> Option<T> {
        if (self.len) == 0 {
            return Option::None;
        }

        let popped_ele = self[self.len() - 1];
        self.len = self.len - 1;
        Option::Some(popped_ele)
    }

    /// takes a Felt252Vec<T> and returns a new Felt252Vec<T> with the same elements
    ///
    /// Note: this is an expensive operation, as it will create a new Felt252Vec
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    ///
    /// # Returns
    /// * A new Felt252Vec<T> with the same elements
    fn duplicate(ref self: Felt252Vec<T>) -> Felt252Vec<T> {
        let mut new_vec = Default::default();

        for i in 0..self.len {
            new_vec.push(self[i]);
        };

        new_vec
    }

    /// Returns a new Felt252Vec<T> with elements starting from `idx` to `idx + len`
    ///
    /// This function will start cloning from `idx` and will clone `len` elements, it will firstly
    /// clone the elements and then return a new Felt252Vec<T>
    /// In case of overflow return Option::None
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `idx` the index to start cloning from
    /// * `len` the length of the clone
    ///
    /// # Returns
    /// * Felt252Vec<T>
    ///
    /// # Panics
    /// * If the index is out of bounds
    ///
    /// Note: this is an expensive operation, as it will create a new Felt252Vec
    fn clone_slice(ref self: Felt252Vec<T>, idx: usize, len: usize) -> Felt252Vec<T> {
        let mut new_vec = Default::default();

        for i in 0..len {
            new_vec.push(self[idx + i]);
        };

        new_vec
    }

    /// Returns whether two Felt252Vec<T> are equal after removing trailing_zeroes
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `rhs` a ref Felt252Vec<T>
    ///
    /// # Returns
    /// * bool, returns true if both Felt252Vecs are equal, false otherwise
    /// TODO: if this utils is only used for testing, then refactor as a test util
    fn equal_remove_trailing_zeroes(ref self: Felt252Vec<T>, ref rhs: Felt252Vec<T>) -> bool {
        let mut lhs = self.duplicate();
        lhs.remove_trailing_zeroes();

        let mut rhs = rhs.duplicate();
        rhs.remove_trailing_zeroes();

        if lhs.len() != rhs.len() {
            return false;
        };

        let mut result = true;
        for i in 0..lhs.len() {
            if lhs[i] != rhs[i] {
                result = false;
                break;
            }
        };
        result
    }

    /// Fills a Felt252Vec<T> with a given `value` starting from `start_idx` to `start_idx + len`
    /// In case of index out of bounds or overflow, error is returned
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `start_idx` the index to start filling from
    /// * `len` the length of the fill
    /// * `value` the value to fill the Felt252Vec with
    ///
    /// # Returns
    /// * Result::<(), Felt252VecTraitErrors>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::IndexOutOfBound if the index is out of bounds
    /// * Felt252VecTraitErrors::Overflow if the Felt252Vec is too big to fit in the Felt252Vec
    fn fill(
        ref self: Felt252Vec<T>, start_idx: usize, len: usize, value: T
    ) -> Result<(), Felt252VecTraitErrors> {
        // Index out of bounds
        if (start_idx >= self.len()) {
            return Result::Err(Felt252VecTraitErrors::IndexOutOfBound);
        }

        // Overflow
        if (start_idx + len > self.len()) {
            return Result::Err(Felt252VecTraitErrors::Overflow);
        }

        for i in start_idx..start_idx + len {
            self.set(i, value);
        };

        Result::Ok(())
    }
}

#[cfg(test)]
mod tests {
    mod felt252_vec_u8_test {
        use alexandria_data_structures::vec::{VecTrait, Felt252Vec};
        use crate::felt_vec::{Felt252VecTrait};

        #[test]
        fn test_felt252_vec_u8_to_bytes() {
            let mut vec: Felt252Vec<u8> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(2);
            vec.push(3);

            let result = vec.to_le_bytes();
            let expected = [0, 1, 2, 3].span();

            assert_eq!(result, expected);
        }
    }

    mod felt252_vec_u64_test {
        use alexandria_data_structures::vec::{VecTrait, Felt252Vec};
        use crate::felt_vec::{Felt252VecTrait};

        #[test]
        fn test_felt252_vec_u64_words64_to_le_bytes() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(2);
            vec.push(3);

            let result = vec.to_le_bytes();
            let expected = [0, 1, 2, 3].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_felt252_vec_u64_words64_to_be_bytes() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(2);
            vec.push(3);

            let result = vec.to_be_bytes();
            let expected = [
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                3,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                2,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0
            ].span();

            assert_eq!(result, expected);
        }
    }

    mod felt252_vec_test {
        use alexandria_data_structures::vec::{VecTrait, Felt252Vec};
        use crate::felt_vec::{Felt252VecTrait, Felt252VecTraitErrors};

        #[test]
        fn test_felt252_vec_expand() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.expand(4).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_expand_fail() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            let result = vec.expand(1);
            assert_eq!(result, Result::Err(Felt252VecTraitErrors::SizeLessThanCurrentLength));
        }

        #[test]
        fn test_felt252_vec_reset() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.reset();

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_count_leading_zeroes() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(0);
            vec.push(0);
            vec.push(1);

            let result = vec.count_leading_zeroes();

            assert_eq!(result, 3);
        }


        #[test]
        fn test_felt252_vec_resize_len_greater_than_current_len() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.expand(4).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_resize_len_less_than_current_len() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(0);
            vec.push(0);

            vec.resize(2);

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_len_0() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.resize(0);

            assert_eq!(vec.len(), 0);
        }

        #[test]
        fn test_copy_from_bytes_le_size_equal_to_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = [1, 2, 3, 4].span();
            vec.copy_from_bytes_le(0, bytes).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 4);
            assert_eq!(vec.pop().unwrap(), 3);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_copy_from_bytes_le_size_less_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = [1, 2].span();
            vec.copy_from_bytes_le(2, bytes).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_copy_from_bytes_le_size_greater_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = [1, 2, 3, 4].span();
            let result = vec.copy_from_bytes_le(2, bytes);

            assert_eq!(result, Result::Err(Felt252VecTraitErrors::Overflow));
        }

        #[test]
        fn test_copy_from_bytes_index_out_of_bound() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = [1, 2].span();
            let result = vec.copy_from_bytes_le(4, bytes);

            assert_eq!(result, Result::Err(Felt252VecTraitErrors::IndexOutOfBound));
        }

        #[test]
        fn test_copy_from_vec_le() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            vec.copy_from_vec_le(ref vec2).unwrap();

            assert_eq!(vec.len, 2);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_copy_from_vec_le_not_equal_lengths() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);

            let result = vec.copy_from_vec_le(ref vec2);

            assert_eq!(result, Result::Err(Felt252VecTraitErrors::LengthIsNotSame));
        }


        #[test]
        fn test_insert_vec_size_equal_to_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            vec.insert_vec(0, ref vec2).unwrap();

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_insert_vec_size_less_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            vec.insert_vec(2, ref vec2).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_insert_vec_size_greater_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);
            vec2.push(3);
            vec2.push(4);

            let result = vec.insert_vec(1, ref vec2);
            assert_eq!(result, Result::Err(Felt252VecTraitErrors::Overflow));
        }

        #[test]
        fn test_insert_vec_index_out_of_bound() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            let result = vec.insert_vec(4, ref vec2);
            assert_eq!(result, Result::Err(Felt252VecTraitErrors::IndexOutOfBound));
        }

        #[test]
        fn test_remove_trailing_zeroes_le() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);
            vec.push(0);
            vec.push(0);

            vec.remove_trailing_zeroes();

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_pop() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop(), Option::<u64>::None);
        }

        #[test]
        fn test_duplicate() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            let mut vec2 = vec.duplicate();

            assert_eq!(vec.len(), vec2.len());
            assert_eq!(vec.pop(), vec2.pop());
            assert_eq!(vec.pop(), vec2.pop());
            assert_eq!(vec.pop().is_none(), true);
            assert_eq!(vec2.pop().is_none(), true);
        }

        #[test]
        fn test_clone_slice() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            let mut vec2 = vec.clone_slice(1, 1);

            assert_eq!(vec2.len(), 1);
            assert_eq!(vec2.pop().unwrap(), 2);
        }

        #[test]
        fn test_equal() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            assert!(vec.equal_remove_trailing_zeroes(ref vec2));
            vec2.pop().unwrap();
            assert!(!vec.equal_remove_trailing_zeroes(ref vec2));
        }

        #[test]
        fn test_fill() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            vec.fill(1, 3, 1).unwrap();

            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_fill_overflow() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            assert_eq!(vec.fill(4, 0, 1), Result::Err(Felt252VecTraitErrors::IndexOutOfBound));
            assert_eq!(vec.fill(2, 4, 1), Result::Err(Felt252VecTraitErrors::Overflow));
        }
    }
}
