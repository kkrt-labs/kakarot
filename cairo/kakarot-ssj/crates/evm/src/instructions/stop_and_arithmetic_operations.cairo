//! Stop and Arithmetic Operations.
use core::integer::{u512_safe_div_rem_by_u256};
use core::math::u256_mul_mod_n;
use core::num::traits::CheckedAdd;
use core::num::traits::{OverflowingAdd, OverflowingMul, OverflowingSub};
use crate::errors::EVMError;
use crate::gas;
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;
use utils::i256::i256;
use utils::math::{Exponentiation, WrappingExponentiation, u256_wide_add};
use utils::traits::integer::BytesUsedTrait;

#[generate_trait]
pub impl StopAndArithmeticOperations of StopAndArithmeticOperationsTrait {
    /// 0x00 - STOP
    /// Halts the execution of the current program.
    /// # Specification: https://www.evm.codes/#00?fork=shanghai
    fn exec_stop(ref self: VM) {
        // return_data store the return_data for the last executed sub context
        // see CALLs opcodes. When it runs the STOP opcode, it stops the current
        // execution context with *no* return data (unlike RETURN and REVERT).
        // hence it just clear the return_data and stop.
        self.return_data = [].span();
        self.stop();
    }

    /// 0x01 - ADD
    /// Addition operation
    /// a + b: integer result of the addition modulo 2^256.
    /// # Specification: https://www.evm.codes/#01?fork=shanghai
    fn exec_add(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;

        // Compute the addition
        let (result, _) = (*popped[0]).overflowing_add(*popped[1]);

        self.stack.push(result)
    }

    /// 0x02 - MUL
    /// Multiplication
    /// a * b: integer result of the multiplication modulo 2^256.
    /// # Specification: https://www.evm.codes/#02?fork=shanghai
    fn exec_mul(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;
        let popped = self.stack.pop_n(2)?;

        // Compute the multiplication
        let (result, _) = (*popped[0]).overflowing_mul(*popped[1]);

        self.stack.push(result)
    }

    /// 0x03 - SUB
    /// Subtraction operation
    /// a - b: integer result of the subtraction modulo 2^256.
    /// # Specification: https://www.evm.codes/#03?fork=shanghai
    fn exec_sub(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;
        let popped = self.stack.pop_n(2)?;

        // Compute the subtraction
        let (result, _) = (*popped[0]).overflowing_sub(*popped[1]);

        self.stack.push(result)
    }

    /// 0x04 - DIV
    /// If the denominator is 0, the result will be 0.
    /// a / b: integer result of the integer division.
    /// # Specification: https://www.evm.codes/#04?fork=shanghai
    fn exec_div(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;
        let popped = self.stack.pop_n(2)?;

        let a: u256 = *popped[0];
        let b: u256 = *popped[1];

        let result: u256 = match TryInto::<u256, NonZero<u256>>::try_into(b) {
            Option::Some(_) => {
                // Won't panic because b is not zero
                a / b
            },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x05 - SDIV
    /// Signed division operation
    /// a / b: integer result of the signed integer division.
    /// If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#05?fork=shanghai
    fn exec_sdiv(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;
        let a: i256 = self.stack.pop_i256()?;
        let b: i256 = self.stack.pop_i256()?;

        let result: u256 = if b == 0_u256.into() {
            0
        } else {
            (a / b).into()
        };
        self.stack.push(result)
    }

    /// 0x06 - MOD
    /// Modulo operation
    /// a % b: integer result of the integer modulo. If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#06?fork=shanghai
    fn exec_mod(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;
        let popped = self.stack.pop_n(2)?;

        let a: u256 = *popped[0];
        let b: u256 = *popped[1];

        let result: u256 = match TryInto::<u256, NonZero<u256>>::try_into(b) {
            Option::Some(_) => {
                // Won't panic because b is not zero
                a % b
            },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x07 - SMOD
    /// Signed modulo operation
    /// a % b: integer result of the signed integer modulo. If the denominator is 0, the result will
    /// be 0.
    /// All values are treated as two’s complement signed 256-bit integers. Note the overflow
    /// semantic when −2^255 is negated.
    /// # Specification: https://www.evm.codes/#07?fork=shanghai
    fn exec_smod(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;
        let a: i256 = self.stack.pop_i256()?;
        let b: i256 = self.stack.pop_i256()?;

        let result: u256 = if b == 0_u256.into() {
            0
        } else {
            (a % b).into()
        };
        self.stack.push(result)
    }

    /// 0x08 - ADDMOD
    /// Addition and modulo operation
    /// (a + b) % N: integer result of the addition followed by a modulo. If the denominator is 0,
    /// the result will be 0.
    /// All intermediate calculations of this operation are not subject to the 2256 modulo.
    /// # Specification: https://www.evm.codes/#08?fork=shanghai
    fn exec_addmod(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::MID)?;
        let popped = self.stack.pop_n(3)?;

        let a: u256 = *popped[0];
        let b: u256 = *popped[1];
        let n = *popped[2];

        let result: u256 = match TryInto::<u256, NonZero<u256>>::try_into(n) {
            Option::Some(nonzero_n) => {
                let sum = u256_wide_add(a, b);
                let (_, r) = u512_safe_div_rem_by_u256(sum, nonzero_n);
                r
            },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x09 - MULMOD operation.
    /// (a * b) % N: integer result of the multiplication followed by a modulo.
    /// All intermediate calculations of this operation are not subject to the 2^256 modulo.
    /// If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#09?fork=shanghai
    fn exec_mulmod(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::MID)?;
        let a: u256 = self.stack.pop()?;
        let b: u256 = self.stack.pop()?;
        let n = self.stack.pop()?;

        let result: u256 = match TryInto::<u256, NonZero<u256>>::try_into(n) {
            Option::Some(n_nz) => { u256_mul_mod_n(a, b, n_nz) },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x0A - EXP
    /// Exponential operation
    /// a ** b: integer result of raising a to the bth power modulo 2^256.
    /// # Specification: https://www.evm.codes/#0a?fork=shanghai
    fn exec_exp(ref self: VM) -> Result<(), EVMError> {
        let base = self.stack.pop()?;
        let exponent = self.stack.pop()?;

        // Gas
        let bytes_used = exponent.bytes_used();
        let total_cost = gas::EXP
            .checked_add(gas::EXP_GAS_PER_BYTE * bytes_used.into())
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;

        let result = base.wrapping_pow(exponent);

        self.stack.push(result)
    }

    /// 0x0B - SIGNEXTEND
    /// SIGNEXTEND takes two inputs `b` and `x` where x: integer value to sign extend
    /// and b: size in byte - 1 of the integer to sign extend and extends the length of
    /// x as a two’s complement signed integer.
    /// The first `i` bits of the output (numbered from the /!\LEFT/!\ counting from zero)
    /// are equal to the `t`-th bit of `x`, where `t` is equal to
    /// `256 - 8(b + 1)`. The remaining bits of the output are equal to the corresponding bits of
    /// `x`.
    /// If b >= 32, then the output is x because t<=0.
    /// To efficiently implement this algorithm we can implement it using a mask, which is all
    /// zeroes until the t-th bit included, and all ones afterwards. The index of `t` when numbered
    /// from the RIGHT is s = `255 - t` = `8b + 7`; so the integer value of the mask used is 2^s -
    /// 1.
    /// Let v be the t-th bit of x. If v == 1, then the output should be all 1s until the t-th bit
    /// included, followed by the remaining bits of x; which is corresponds to (x | !mask).
    /// If v == 0, then the output should be all 0s until the t-th bit included, followed by the
    /// remaining bits of x;
    /// which corresponds to (x & mask).
    /// # Specification: https://www.evm.codes/#0b?fork=shanghai
    /// Complex opcode, check: https://ethereum.github.io/yellowpaper/paper.pdf
    fn exec_signextend(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;
        let b = self.stack.pop()?;
        let x = self.stack.pop()?;

        let result = if b < 32 {
            let s = 8 * b + 7;
            //TODO: use POW_2 table for optimization
            let two_pow_s = 2.pow(s);
            // Get v, the t-th bit of x. To do this we bitshift x by s bits to the right and apply a
            // mask to get the last bit.
            let v = (x / two_pow_s) & 1;
            // Compute the mask with 8b+7 bits set to one
            let mask = two_pow_s - 1;
            if v == 0 {
                x & mask
            } else {
                x | ~mask
            }
        } else {
            x
        };

        self.stack.push(result)
    }
}

#[cfg(test)]
mod tests {
    use core::num::traits::Bounded;
    use core::result::ResultTrait;
    use crate::instructions::StopAndArithmeticOperationsTrait;
    use crate::model::vm::VMTrait;
    use crate::stack::StackTrait;
    use crate::test_utils::VMBuilderTrait;


    #[test]
    fn test_exec_stop_should_stop_and_empty_return_data() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.return_data = [1, 2, 3].span();
        // When
        vm.exec_stop();

        // Then
        assert!(!vm.is_running());
        assert_eq!(vm.return_data, [].span());
    }

    #[test]
    fn test_exec_add() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(1).expect('push failed');
        vm.stack.push(2).expect('push failed');
        vm.stack.push(3).expect('push failed');

        // When
        vm.exec_add().expect('exec_add failed');

        // Then
        assert(vm.stack.len() == 2, 'stack should have two elems');
        assert(vm.stack.peek().unwrap() == 5, 'stack top should be 3+2');
        assert(vm.stack.peek_at(1).unwrap() == 1, 'stack[1] should be 1');
    }

    #[test]
    fn test_exec_add_overflow() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(Bounded::<u256>::MAX).unwrap();
        vm.stack.push(1).expect('push failed');

        // When
        vm.exec_add().expect('exec_add failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    #[test]
    fn test_exec_mul() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(4).expect('push failed');
        vm.stack.push(5).expect('push failed');

        // When
        vm.exec_mul().expect('exec_mul failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 20, 'stack top should be 4*5');
    }

    #[test]
    fn test_exec_mul_overflow() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(Bounded::<u256>::MAX).unwrap();
        vm.stack.push(2).expect('push failed');

        // When
        vm.exec_mul().expect('exec_mul failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == Bounded::<u256>::MAX - 1, 'expected MAX_U256 -1');
    }

    #[test]
    fn test_exec_sub() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(7).expect('push failed');
        vm.stack.push(10).expect('push failed');

        // When
        vm.exec_sub().expect('exec_sub failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 3, 'stack top should be 10-7');
    }

    #[test]
    fn test_exec_sub_underflow() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(1).expect('push failed');
        vm.stack.push(0).expect('push failed');

        // When
        vm.exec_sub().expect('exec_sub failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == Bounded::<u256>::MAX, 'stack top should be MAX_U256');
    }


    #[test]
    fn test_exec_div() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(4).expect('push failed');
        vm.stack.push(100).expect('push failed');

        // When
        vm.exec_div().expect('exec_div failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 25, 'stack top should be 100/4');
    }

    #[test]
    fn test_exec_div_by_zero() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(100).expect('push failed');

        // When
        vm.exec_div().expect('exec_div failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    #[test]
    fn test_exec_sdiv_pos() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(5).expect('push failed');
        vm.stack.push(10).expect('push failed');

        // When
        vm.exec_sdiv().expect('exec_sdiv failed'); // 10 / 5

        // Then
        assert(vm.stack.len() == 1, 'stack len should be 1');
        assert(vm.stack.peek().unwrap() == 2, 'ctx not stopped');
    }

    #[test]
    fn test_exec_sdiv_neg() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(Bounded::MAX).unwrap();
        vm.stack.push(2).expect('push failed');

        // When
        vm.exec_sdiv().expect('exec_sdiv failed'); // 2 / -1

        // Then
        assert(vm.stack.len() == 1, 'stack len should be 1');
        assert(vm.stack.peek().unwrap() == Bounded::MAX - 1, 'sdiv_neg failed');
    }

    #[test]
    fn test_exec_sdiv_by_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(10).expect('push failed');

        // When
        vm.exec_sdiv().expect('exec_sdiv failed');

        // Then
        assert(vm.stack.len() == 1, 'stack len should be 1');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    #[test]
    fn test_exec_mod() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(6).expect('push failed');
        vm.stack.push(100).expect('push failed');

        // When
        vm.exec_mod().expect('exec_mod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 4, 'stack top should be 100%6');
    }

    #[test]
    fn test_exec_mod_by_zero() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(100).expect('push failed');

        // When
        vm.exec_smod().expect('exec_smod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 100%6');
    }

    #[test]
    fn test_exec_smod() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(3).expect('push failed');
        vm.stack.push(10).expect('push failed');

        // When
        vm.exec_smod().expect('exec_smod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 1, 'stack top should be 10%3 = 1');
    }

    #[test]
    fn test_exec_smod_neg() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD)
            .unwrap(); // -3
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8)
            .unwrap(); // -8

        // When
        vm.exec_smod().expect('exec_smod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm
                .stack
                .peek()
                .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
            'stack top should be -8%-3 = -2'
        );
    }

    #[test]
    fn test_exec_smod_zero() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(10).expect('push failed');

        // When
        vm.exec_mod().expect('exec_mod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }


    #[test]
    fn test_exec_addmod() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(7).expect('push failed');
        vm.stack.push(10).expect('push failed');
        vm.stack.push(20).expect('push failed');

        // When
        vm.exec_addmod().expect('exec_addmod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 2, 'stack top should be (10+20)%7');
    }

    #[test]
    fn test_exec_addmod_by_zero() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(10).expect('push failed');
        vm.stack.push(20).expect('push failed');

        // When
        vm.exec_addmod().expect('exec_addmod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }


    #[test]
    fn test_exec_addmod_overflow() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(3).expect('push failed');
        vm.stack.push(2).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).unwrap();

        // When
        vm.exec_addmod().expect('exec_addmod failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm.stack.peek().unwrap() == 2, 'stack top should be 2'
        ); // (MAX_U256 + 2) % 3 = (2^256 + 1) % 3 = 2
    }

    #[test]
    fn test_mulmod_basic() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(10).expect('push failed');
        vm.stack.push(7).expect('push failed');
        vm.stack.push(5).expect('push failed');

        // When
        vm.exec_mulmod().expect('exec_mulmod failed');

        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 5, 'stack top should be 5'); // (5 * 7) % 10 = 5
    }

    #[test]
    fn test_mulmod_zero_modulus() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(7).expect('push failed');
        vm.stack.push(5).expect('push failed');

        vm.exec_mulmod().expect('exec_mulmod failed');

        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0'); // modulus is 0
    }

    #[test]
    fn test_mulmod_overflow() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(12).expect('push failed');
        vm.stack.push(Bounded::<u256>::MAX).unwrap();
        vm.stack.push(Bounded::<u256>::MAX).unwrap();

        vm.exec_mulmod().expect('exec_mulmod failed');

        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm.stack.peek().unwrap() == 9, 'stack top should be 1'
        ); // (MAX_U256 * MAX_U256) % 12 = 9
    }

    #[test]
    fn test_mulmod_zero() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(10).expect('push failed');
        vm.stack.push(7).expect('push failed');
        vm.stack.push(0).expect('push failed');

        vm.exec_mulmod().expect('exec_mulmod failed');

        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0'); // 0 * 7 % 10 = 0
    }

    #[test]
    fn test_exec_exp() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let initial_gas = vm.gas_left();
        vm.stack.push(2).expect('push failed');
        vm.stack.push(10).expect('push failed');

        // When
        vm.exec_exp().expect('exec exp failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 100, 'stack top should be 100');
        let expected_gas_used = 10 + 50 * 1;
        assert_eq!(initial_gas - vm.gas_left(), expected_gas_used);
    }

    #[test]
    fn test_exec_exp_overflow() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let initial_gas = vm.gas_left();
        vm.stack.push(2).expect('push failed');
        vm.stack.push(Bounded::<u128>::MAX.into() + 1).unwrap();

        // When
        vm.exec_exp().expect('exec exp failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm.stack.peek().unwrap() == 0, 'stack top should be 0'
        ); // (2^128)^2 = 2^256 = 0 % 2^256
        let expected_gas_used = 10 + 50 * 1;
        assert_eq!(initial_gas - vm.gas_left(), expected_gas_used);
    }

    #[test]
    fn test_exec_signextend() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0xFF).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        vm.exec_signextend().expect('exec_signextend failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm
                .stack
                .peek()
                .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            'stack top should be MAX_u256 -1'
        );
    }

    #[test]
    fn test_exec_signextend_no_effect() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm.stack.push(0x7F).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        // When
        vm.exec_signextend().expect('exec_signextend failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm.stack.peek().unwrap() == 0x7F, 'stack top should be 0x7F'
        ); // The 248-th bit of x is 0, so the output is not changed.
    }

    #[test]
    fn test_exec_signextend_on_negative() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0001)
            .expect('push failed');
        vm.stack.push(0x01).expect('push failed'); // s = 15, v = 0

        // When
        vm.exec_signextend().expect('exec_signextend failed');

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(
            vm.stack.peek().unwrap() == 0x01, 'stack top should be 0'
        ); // The 241-th bit of x is 0, so all bits before t are switched to 0
    }
}
