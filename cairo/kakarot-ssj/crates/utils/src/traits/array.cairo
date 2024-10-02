#[generate_trait]
pub impl ArrayExtension<T, +Drop<T>> of ArrayExtTrait<T> {
    /// Concatenates two arrays by adding the elements of `arr2` to `self`.
    ///
    /// # Arguments
    ///
    /// * `self` - The array to append to.
    /// * `arr2` - The array to append from.
    fn concat<+Copy<T>>(ref self: Array<T>, mut arr2: Span<T>) {
        for elem in arr2 {
            self.append(*elem);
        };
    }

    /// Reverses an array.
    ///
    /// # Arguments
    ///
    /// * `self` - The array to reverse.
    ///
    /// # Returns
    ///
    /// A new `Array<T>` with the elements in reverse order.
    fn reverse<+Copy<T>>(self: Span<T>) -> Array<T> {
        let mut counter = self.len();
        let mut dst: Array<T> = ArrayTrait::new();
        while counter != 0 {
            dst.append(*self[counter - 1]);
            counter -= 1;
        };
        dst
    }

    /// Appends a value to the array `n` times.
    ///
    /// # Arguments
    ///
    /// * `self` - The array to append to.
    /// * `value` - The value to append.
    /// * `n` - The number of times to append the value.
    fn append_n<+Copy<T>>(ref self: Array<T>, value: T, mut n: usize) {
        for _ in 0..n {
            self.append(value);
        };
    }

    /// Appends an item only if it is not already in the array.
    ///
    /// # Arguments
    ///
    /// * `self` - The array to append to.
    /// * `value` - The value to append if not present.
    fn append_unique<+Copy<T>, +PartialEq<T>>(ref self: Array<T>, value: T) {
        if self.span().contains(value) {
            return ();
        }
        self.append(value);
    }

    /// Concatenates two arrays by adding the unique elements of `arr2` to `self`.
    ///
    /// # Arguments
    ///
    /// * `self` - The array to append to.
    /// * `arr2` - The array to append from.
    fn concat_unique<+Copy<T>, +PartialEq<T>>(ref self: Array<T>, mut arr2: Span<T>) {
        for elem in arr2 {
            self.append_unique(*elem)
        };
    }
}

#[generate_trait]
pub impl SpanExtension<T, +Copy<T>, +Drop<T>> of SpanExtTrait<T> {
    /// Returns true if the array contains an item.
    ///
    /// # Arguments
    ///
    /// * `self` - The array to search.
    /// * `value` - The value to search for.
    ///
    /// # Returns
    ///
    /// `true` if the value is found, `false` otherwise.
    fn contains<+PartialEq<T>>(mut self: Span<T>, value: T) -> bool {
        let mut result = false;
        for elem in self {
            if *elem == value {
                result = true;
            }
        };
        result
    }

    /// Returns the index of an item in the array.
    ///
    /// # Arguments
    ///
    /// * `self` - The array to search.
    /// * `value` - The value to search for.
    ///
    /// # Returns
    ///
    /// `Option::Some(index)` if the value is found, `Option::None` otherwise.
    fn index_of<+PartialEq<T>>(mut self: Span<T>, value: T) -> Option<u128> {
        let mut i = 0;
        let mut result = Option::None;
        for elem in self {
            if *elem == value {
                result = Option::Some(i);
            }
            i += 1;
        };
        return result;
    }
}

#[cfg(test)]
mod tests {
    mod test_array_ext {
        use super::super::{ArrayExtTrait};
        #[test]
        fn test_append_n() {
            // Given
            let mut original: Array<u8> = array![1, 2, 3, 4];

            // When
            original.append_n(9, 3);

            // Then
            assert(original == array![1, 2, 3, 4, 9, 9, 9], 'append_n failed');
        }

        #[test]
        fn test_append_unique() {
            let mut arr = array![1, 2, 3];
            arr.append_unique(4);
            assert(arr == array![1, 2, 3, 4], 'should have appended');
            arr.append_unique(2);
            assert(arr == array![1, 2, 3, 4], 'shouldnt have appended');
        }
    }
}
