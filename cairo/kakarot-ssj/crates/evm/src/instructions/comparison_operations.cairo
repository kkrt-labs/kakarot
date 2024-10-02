use core::num::traits::Bounded;
use crate::errors::EVMError;
use crate::gas;
use crate::model::vm::{VM, VMTrait};
// Internal imports
use crate::stack::StackTrait;
use utils::constants::{POW_2_127};
use utils::i256::i256;
use utils::math::{Bitshift, WrappingBitshift};
use utils::traits::BoolIntoNumeric;

#[generate_trait]
pub impl ComparisonAndBitwiseOperations of ComparisonAndBitwiseOperationsTrait {
    /// 0x10 - LT
    /// # Specification: https://www.evm.codes/#10?fork=shanghai
    fn exec_lt(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = (a < b).into();
        self.stack.push(result)
    }

    /// 0x11 - GT
    /// # Specification: https://www.evm.codes/#11?fork=shanghai
    fn exec_gt(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = (a > b).into();
        self.stack.push(result)
    }


    /// 0x12 - SLT
    /// # Specification: https://www.evm.codes/#12?fork=shanghai
    fn exec_slt(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let a: i256 = self.stack.pop_i256()?;
        let b: i256 = self.stack.pop_i256()?;
        let result: u256 = (a < b).into();
        self.stack.push(result)
    }

    /// 0x13 - SGT
    /// # Specification: https://www.evm.codes/#13?fork=shanghai
    fn exec_sgt(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let a: i256 = self.stack.pop_i256()?;
        let b: i256 = self.stack.pop_i256()?;
        let result: u256 = (a > b).into();
        self.stack.push(result)
    }


    /// 0x14 - EQ
    /// # Specification: https://www.evm.codes/#14?fork=shanghai
    fn exec_eq(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = (a == b).into();
        self.stack.push(result)
    }

    /// 0x15 - ISZERO
    /// # Specification: https://www.evm.codes/#15?fork=shanghai
    fn exec_iszero(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop()?;
        let result: u256 = (popped == 0).into();
        self.stack.push(result)
    }

    /// 0x16 - AND
    /// # Specification: https://www.evm.codes/#16?fork=shanghai
    fn exec_and(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = a & b;
        self.stack.push(result)
    }

    /// 0x17 - OR
    /// # Specification: https://www.evm.codes/#17?fork=shanghai
    fn exec_or(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = a | b;
        self.stack.push(result)
    }

    /// 0x18 - XOR operation
    /// # Specification: https://www.evm.codes/#18?fork=shanghai
    fn exec_xor(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = a ^ b;
        self.stack.push(result)
    }

    /// 0x19 - NOT
    /// Bitwise NOT operation
    /// # Specification: https://www.evm.codes/#19?fork=shanghai
    fn exec_not(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let a = self.stack.pop()?;
        let result = ~a;
        self.stack.push(result)
    }

    /// 0x1A - BYTE
    /// # Specification: https://www.evm.codes/#1a?fork=shanghai
    /// Retrieve single byte located at the byte offset of value, starting from the most significant
    /// byte.
    fn exec_byte(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let i = *popped[0];
        let x = *popped[1];

        /// If the byte offset is out of range, we early return with 0.
        if i > 31 {
            return self.stack.push(0);
        }
        let i: usize = i.try_into().unwrap(); // Safe because i <= 31

        // Right shift value by offset bits and then take the least significant byte.
        let result = x.shr((31 - i) * 8) & 0xFF;
        self.stack.push(result)
    }

    /// 0x1B - SHL
    /// # Specification: https://www.evm.codes/#1b?fork=shanghai
    fn exec_shl(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let shift = *popped[0];
        let val = *popped[1];

        // if shift is bigger than 255 return 0
        if shift > 255 {
            return self.stack.push(0);
        }
        let shift: usize = shift.try_into().unwrap(); // Safe because shift <= 255
        let result = val.wrapping_shl(shift);
        self.stack.push(result)
    }

    /// 0x1C - SHR
    /// # Specification: https://www.evm.codes/#1c?fork=shanghai
    fn exec_shr(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;
        let shift = *popped[0];
        let value = *popped[1];

        // if shift is bigger than 255 return 0
        if shift > 255 {
            return self.stack.push(0);
        }
        let shift: usize = shift.try_into().unwrap(); // Safe because shift <= 255
        let result = value.wrapping_shr(shift);
        self.stack.push(result)
    }

    /// 0x1D - SAR
    /// # Specification: https://www.evm.codes/#1d?fork=shanghai
    fn exec_sar(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let shift: u256 = self.stack.pop()?;
        let value: i256 = self.stack.pop_i256()?;

        // Checks the MSB bit sign for a 256-bit integer
        let positive = value.value.high < POW_2_127;
        let sign = if positive {
            // If sign is positive, set it to 0.
            0
        } else {
            // If sign is negative, set the number to -1.
            Bounded::<u256>::MAX
        };

        if (shift >= 256) {
            self.stack.push(sign)
        } else {
            let shift: usize = shift.try_into().unwrap(); // Safe because shift <= 256
            // XORing with sign before and after the shift propagates the sign bit of the operation
            let result = (sign ^ value.value).shr(shift) ^ sign;
            self.stack.push(result)
        }
    }
}


#[cfg(test)]
mod tests {
    use core::num::traits::Bounded;
    use crate::instructions::ComparisonAndBitwiseOperationsTrait;
    use crate::stack::StackTrait;
    use crate::test_utils::VMBuilderTrait;

    #[test]
    fn test_eq_same_pair() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210)
            .expect('push failed');
        vm
            .stack
            .push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210)
            .expect('push failed');

        // When
        vm.exec_eq().expect('exec_eq failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x01, 'stack top should be 0x01');
    }

    #[test]
    fn test_eq_different_pair() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xAB8765432DCBA98765410F149E87610FDCBA98765432543217654DCBA93210F8)
            .expect('push failed');
        vm
            .stack
            .push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210)
            .expect('push failed');

        // When
        vm.exec_eq().expect('exec_eq failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
    }

    #[test]
    fn test_and_zero_and_max() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).unwrap();

        // When
        vm.exec_and().expect('exec_and failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
    }

    #[test]
    fn test_and_max_and_max() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(Bounded::<u256>::MAX).unwrap();
        vm.stack.push(Bounded::<u256>::MAX).unwrap();

        // When
        vm.exec_and().expect('exec_and failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == Bounded::<u256>::MAX, 'stack top should be 0xFF...FFF');
    }

    #[test]
    fn test_and_two_random_uint() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xAB8765432DCBA98765410F149E87610FDCBA98765432543217654DCBA93210F8)
            .expect('push failed');
        vm
            .stack
            .push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210)
            .expect('push failed');

        // When
        vm.exec_and().expect('exec_and failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm
                .stack
                .peek()
                .unwrap() == 0xAA8420002440200064400A1016042000DC989810541010101644088820101010,
            'stack top is wrong'
        );
    }


    #[test]
    fn test_xor_different_pair() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0b010101).expect('push failed');
        vm.stack.push(0b101010).expect('push failed');

        // When
        vm.exec_xor().expect('exec_xor failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0b111111, 'stack top should be 0xFF');
    }

    #[test]
    fn test_xor_same_pair() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0b000111).expect('push failed');
        vm.stack.push(0b000111).expect('push failed');

        // When
        vm.exec_xor().expect('exec_xor failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
    }

    #[test]
    fn test_xor_half_same_pair() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0b111000).expect('push failed');
        vm.stack.push(0b000000).expect('push failed');

        // When
        vm.exec_xor().expect('exec_xor failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0b111000, 'stack top should be 0xFF');
    }


    #[test]
    fn test_not_zero() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x00).expect('push failed');

        // When
        vm.exec_not().expect('exec_not failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == Bounded::<u256>::MAX, 'stack top should be 0xFFF..FFFF');
    }

    #[test]
    fn test_not_max_uint() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(Bounded::<u256>::MAX).unwrap();

        // When
        vm.exec_not().expect('exec_not failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
    }

    #[test]
    fn test_not_random_uint() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0x123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF1234)
            .expect('push failed');

        // When
        vm.exec_not().expect('exec_not failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm
                .stack
                .peek()
                .unwrap() == 0xEDCBA9876543210EDCBA9876543210EDCBA9876543210EDCBA9876543210EDCB,
            'stack top should be 0x7553'
        );
    }

    #[test]
    fn test_is_zero_true() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x00).expect('push failed');

        // When
        vm.exec_iszero().expect('exec_iszero failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x01, 'stack top should be true');
    }

    #[test]
    fn test_is_zero_false() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x01).expect('push failed');

        // When
        vm.exec_iszero().expect('exec_iszero failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be false');
    }

    #[test]
    fn test_byte_random_u256() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xf7ec8b2ea4a6b7fd5f4ed41b66197fcc14c4a37d68275ea151d899bb4d7c2ae7)
            .expect('push failed');
        vm.stack.push(0x08).expect('push failed');

        // When
        vm.exec_byte().expect('exec_byte failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x5f, 'stack top should be 0x22');
    }

    #[test]
    fn test_byte_offset_out_of_range() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0x01be893aefcfa1592f60622b80d45c2db74281d2b9e10c14b0f6ce7c8f58e209)
            .expect('push failed');
        vm.stack.push(32_u256).expect('push failed');

        // When
        vm.exec_byte().expect('exec_byte failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
    }

    #[test]
    fn test_exec_gt_true() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(9_u256).expect('push failed');
        vm.stack.push(10_u256).expect('push failed');

        // When
        vm.exec_gt().expect('exec_gt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 1, 'stack top should be 1');
    }

    #[test]
    fn test_exec_shl() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xff00000000000000000000000000000000000000000000000000000000000000)
            .expect('push failed');
        vm.stack.push(4_u256).expect('push failed');

        // When
        vm.exec_shl().expect('exec_shl failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm
                .stack
                .peek()
                .unwrap() == 0xf000000000000000000000000000000000000000000000000000000000000000,
            'stack top should be 0xf00000...'
        );
    }

    #[test]
    fn test_exec_shl_wrapping() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xff00000000000000000000000000000000000000000000000000000000000000)
            .expect('push failed');
        vm.stack.push(256_u256).expect('push failed');

        // When
        vm.exec_shl().expect('exec_shl failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'if shift > 255 should return 0');
    }

    #[test]
    fn test_exec_gt_false() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(10_u256).expect('push failed');
        vm.stack.push(9_u256).expect('push failed');

        // When
        vm.exec_gt().expect('exec_gt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    #[test]
    fn test_exec_gt_false_equal() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(10_u256).expect('push failed');
        vm.stack.push(10_u256).expect('push failed');

        // When
        vm.exec_gt().expect('exec_gt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    #[test]
    fn test_exec_slt() {
        // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_slt.json
        assert_slt(0x0, 0x0, 0);
        assert_slt(0x0, 0x1, 0);
        assert_slt(0x0, 0x5, 0);
        assert_slt(0x0, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0);
        assert_slt(0x0, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
        assert_slt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000000, 1);
        assert_slt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000001, 1);
        assert_slt(0x0, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 1);
        assert_slt(0x0, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
        assert_slt(0x1, 0x0, 1);
        assert_slt(0x1, 0x1, 0);
        assert_slt(0x1, 0x5, 0);
        assert_slt(0x1, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0);
        assert_slt(0x1, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
        assert_slt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000000, 1);
        assert_slt(0x1, 0x8000000000000000000000000000000000000000000000000000000000000001, 1);
        assert_slt(0x1, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 1);
        assert_slt(0x1, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
        assert_slt(0x5, 0x0, 1);
        assert_slt(0x5, 0x1, 1);
        assert_slt(0x5, 0x5, 0);
        assert_slt(0x5, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0);
        assert_slt(0x5, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
        assert_slt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000000, 1);
        assert_slt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000001, 1);
        assert_slt(0x5, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 1);
        assert_slt(0x5, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
        assert_slt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x0, 1);
        assert_slt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x1, 1);
        assert_slt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x5, 1);
        assert_slt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0
        );
        assert_slt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            1
        );
        assert_slt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            1
        );
        assert_slt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            1
        );
        assert_slt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_slt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 1);
        assert_slt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 1);
        assert_slt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 1);
        assert_slt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            1
        );
        assert_slt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            1
        );
        assert_slt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            1
        );
        assert_slt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            1
        );
        assert_slt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_slt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x0, 0);
        assert_slt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x1, 0);
        assert_slt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x5, 0);
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x0, 0);
        assert_slt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x1, 0);
        assert_slt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x5, 0);
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            1
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0
        );
        assert_slt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x0, 0);
        assert_slt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x1, 0);
        assert_slt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x5, 0);
        assert_slt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0
        );
        assert_slt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            1
        );
        assert_slt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            1
        );
        assert_slt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0
        );
        assert_slt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 0);
        assert_slt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 0);
        assert_slt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 0);
        assert_slt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0
        );
        assert_slt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_slt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            1
        );
        assert_slt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            1
        );
        assert_slt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            1
        );
        assert_slt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
    }

    fn assert_slt(b: u256, a: u256, expected: u256) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(b).expect('push failed');
        vm.stack.push(a).expect('push failed');

        // When
        vm.exec_slt().expect('exec_slt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == expected, 'slt failed');
    }

    #[test]
    fn test_exec_sgt() {
        // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_sgt.json
        assert_sgt(0x0, 0x0, 0);
        assert_sgt(0x0, 0x1, 1);
        assert_sgt(0x0, 0x5, 1);
        assert_sgt(0x0, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 1);
        assert_sgt(0x0, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
        assert_sgt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000000, 0);
        assert_sgt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000001, 0);
        assert_sgt(0x0, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0);
        assert_sgt(0x0, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
        assert_sgt(0x1, 0x0, 0);
        assert_sgt(0x1, 0x1, 0);
        assert_sgt(0x1, 0x5, 1);
        assert_sgt(0x1, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 1);
        assert_sgt(0x1, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
        assert_sgt(0x1, 0x8000000000000000000000000000000000000000000000000000000000000000, 0);
        assert_sgt(0x1, 0x8000000000000000000000000000000000000000000000000000000000000001, 0);
        assert_sgt(0x1, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0);
        assert_sgt(0x1, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
        assert_sgt(0x5, 0x0, 0);
        assert_sgt(0x5, 0x1, 0);
        assert_sgt(0x5, 0x5, 0);
        assert_sgt(0x5, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 1);
        assert_sgt(0x5, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
        assert_sgt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000000, 0);
        assert_sgt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000001, 0);
        assert_sgt(0x5, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0);
        assert_sgt(0x5, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
        assert_sgt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x0, 0);
        assert_sgt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x1, 0);
        assert_sgt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x5, 0);
        assert_sgt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0
        );
        assert_sgt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0
        );
        assert_sgt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0
        );
        assert_sgt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0
        );
        assert_sgt(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_sgt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 0);
        assert_sgt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 0);
        assert_sgt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 0);
        assert_sgt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0
        );
        assert_sgt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_sgt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0
        );
        assert_sgt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0
        );
        assert_sgt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0
        );
        assert_sgt(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
        assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x0, 1);
        assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x1, 1);
        assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x5, 1);
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            1
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            1
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            1
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x0, 1);
        assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x1, 1);
        assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x5, 1);
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            1
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            1
        );
        assert_sgt(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x0, 1);
        assert_sgt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x1, 1);
        assert_sgt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x5, 1);
        assert_sgt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            1
        );
        assert_sgt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0
        );
        assert_sgt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0
        );
        assert_sgt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0
        );
        assert_sgt(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 1);
        assert_sgt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 1);
        assert_sgt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 1);
        assert_sgt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            1
        );
        assert_sgt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            1
        );
        assert_sgt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0
        );
        assert_sgt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0
        );
        assert_sgt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0
        );
        assert_sgt(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0
        );
    }

    fn assert_sgt(b: u256, a: u256, expected: u256) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(b).expect('push failed');
        vm.stack.push(a).expect('push failed');

        // When
        vm.exec_sgt().expect('exec_sgt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == expected, 'sgt failed');
    }

    #[test]
    fn test_exec_shr() {
        // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_shr.json
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000005
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000002
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x4000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0400000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x4000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0400000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_shr(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
    }

    fn assert_shr(a: u256, b: u256, expected: u256) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(a).expect('push failed');
        vm.stack.push(b).expect('push failed');

        // When
        vm.exec_shr().expect('exec_shr failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == expected, 'shr failed');
    }

    #[test]
    fn test_exec_sar() {
        // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_sar.json
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000005
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000002
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xc000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xfc00000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x8000000000000000000000000000000000000000000000000000000000000001
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xc000000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xfc00000000000000000000000000000000000000000000000000000000000000
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x0000000000000000000000000000000000000000000000000000000000000005,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0x8000000000000000000000000000000000000000000000000000000000000001,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assert_sar(
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
    }

    fn assert_sar(a: u256, b: u256, expected: u256) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(a).expect('push failed');
        vm.stack.push(b).expect('push failed');

        // When

        vm.exec_sar().expect('exec_sar failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == expected, 'sar failed');
    }

    #[test]
    fn test_exec_or_should_pop_0_and_1_and_push_0xCD_when_0_is_0x89_and_1_is_0xC5() {
        //Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x89).expect('push failed');
        vm.stack.push(0xC5).expect('push failed');

        //When
        vm.exec_or().expect('exec_or failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0xCD, 'stack top should be 0xCD');
    }

    #[test]
    fn test_or_true() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x01).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        vm.exec_or().expect('exec_or failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x01, 'stack top should be 0x01');
    }

    #[test]
    fn test_or_false() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        vm.exec_or().expect('exec_or failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
    }


    #[test]
    fn test_exec_lt_true() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(10_u256).expect('push failed');
        vm.stack.push(9_u256).expect('push failed');

        // When
        vm.exec_lt().expect('exec_lt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x01, 'stack top should be true');
    }

    #[test]
    fn test_exec_lt_false() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(10_u256).expect('push failed');
        vm.stack.push(20_u256).expect('push failed');

        // When
        vm.exec_lt().expect('exec_lt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be false');
    }

    #[test]
    fn test_exec_lt_false_eq() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(10_u256).expect('push failed');
        vm.stack.push(10_u256).expect('push failed');

        // When
        vm.exec_lt().expect('exec_lt failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0x00, 'stack top should be false');
    }
}
