//! Push Operations.

use crate::errors::EVMError;
use crate::gas;
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;
use utils::traits::bytes::{FromBytes, U8SpanExTrait};

/// Place i bytes items on stack.
#[inline(always)]
fn exec_push_i(ref self: VM, i: u8) -> Result<(), EVMError> {
    self.charge_gas(gas::VERYLOW)?;
    let i = i.into();
    let args_pc = self.pc() + 1; // PUSH_N Arguments begin at pc + 1
    let data = self.read_code(args_pc, i);

    self.set_pc(self.pc() + i);

    if data.len() == 0 {
        self.stack.push(0)
    } else {
        self.stack.push(data.pad_right_with_zeroes(i).from_be_bytes_partial().unwrap())
    }
}

#[generate_trait]
pub impl PushOperations of PushOperationsTrait {
    /// 5F - PUSH0 operation
    /// # Specification: https://www.evm.codes/#5f?fork=shanghai
    #[inline(always)]
    fn exec_push0(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(0)
    }


    /// 0x60 - PUSH1 operation
    /// # Specification: https://www.evm.codes/#60?fork=shanghai
    #[inline(always)]
    fn exec_push1(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 1)
    }


    /// 0x61 - PUSH2 operation
    /// # Specification: https://www.evm.codes/#61?fork=shanghai
    #[inline(always)]
    fn exec_push2(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 2)
    }


    /// 0x62 - PUSH3 operation
    /// # Specification: https://www.evm.codes/#62?fork=shanghai
    #[inline(always)]
    fn exec_push3(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 3)
    }

    /// 0x63 - PUSH4 operation
    /// # Specification: https://www.evm.codes/#63?fork=shanghai
    #[inline(always)]
    fn exec_push4(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 4)
    }

    /// 0x64 - PUSH5 operation
    /// # Specification: https://www.evm.codes/#64?fork=shanghai
    #[inline(always)]
    fn exec_push5(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 5)
    }

    /// 0x65 - PUSH6 operation
    /// # Specification: https://www.evm.codes/#65?fork=shanghai
    #[inline(always)]
    fn exec_push6(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 6)
    }

    /// 0x66 - PUSH7 operation
    /// # Specification: https://www.evm.codes/#66?fork=shanghai
    #[inline(always)]
    fn exec_push7(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 7)
    }

    /// 0x67 - PUSH8 operation
    /// # Specification: https://www.evm.codes/#67?fork=shanghai
    #[inline(always)]
    fn exec_push8(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 8)
    }


    /// 0x68 - PUSH9 operation
    /// # Specification: https://www.evm.codes/#68?fork=shanghai
    #[inline(always)]
    fn exec_push9(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 9)
    }

    /// 0x69 - PUSH10 operation
    /// # Specification: https://www.evm.codes/#69?fork=shanghai
    #[inline(always)]
    fn exec_push10(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 10)
    }

    /// 0x6A - PUSH11 operation
    /// # Specification: https://www.evm.codes/#6a?fork=shanghai
    #[inline(always)]
    fn exec_push11(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 11)
    }

    /// 0x6B - PUSH12 operation
    /// # Specification: https://www.evm.codes/#6b?fork=shanghai
    #[inline(always)]
    fn exec_push12(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 12)
    }


    /// 0x6C - PUSH13 operation
    /// # Specification: https://www.evm.codes/#6c?fork=shanghai
    #[inline(always)]
    fn exec_push13(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 13)
    }

    /// 0x6D - PUSH14 operation
    /// # Specification: https://www.evm.codes/#6d?fork=shanghai
    #[inline(always)]
    fn exec_push14(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 14)
    }


    /// 0x6E - PUSH15 operation
    /// # Specification: https://www.evm.codes/#6e?fork=shanghai
    #[inline(always)]
    fn exec_push15(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 15)
    }

    /// 0x6F - PUSH16 operation
    /// # Specification: https://www.evm.codes/#6f?fork=shanghai
    #[inline(always)]
    fn exec_push16(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 16)
    }

    /// 0x70 - PUSH17 operation
    /// # Specification: https://www.evm.codes/#70?fork=shanghai
    #[inline(always)]
    fn exec_push17(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 17)
    }

    /// 0x71 - PUSH18 operation
    /// # Specification: https://www.evm.codes/#71?fork=shanghai
    #[inline(always)]
    fn exec_push18(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 18)
    }


    /// 0x72 - PUSH19 operation
    /// # Specification: https://www.evm.codes/#72?fork=shanghai
    #[inline(always)]
    fn exec_push19(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 19)
    }

    /// 0x73 - PUSH20 operation
    /// # Specification: https://www.evm.codes/#73?fork=shanghai
    #[inline(always)]
    fn exec_push20(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 20)
    }


    /// 0x74 - PUSH21 operation
    /// # Specification: https://www.evm.codes/#74?fork=shanghai
    #[inline(always)]
    fn exec_push21(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 21)
    }


    /// 0x75 - PUSH22 operation
    /// # Specification: https://www.evm.codes/#75?fork=shanghai
    #[inline(always)]
    fn exec_push22(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 22)
    }


    /// 0x76 - PUSH23 operation
    /// # Specification: https://www.evm.codes/#76?fork=shanghai
    #[inline(always)]
    fn exec_push23(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 23)
    }


    /// 0x77 - PUSH24 operation
    /// # Specification: https://www.evm.codes/#77?fork=shanghai
    #[inline(always)]
    fn exec_push24(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 24)
    }


    /// 0x78 - PUSH21 operation
    /// # Specification: https://www.evm.codes/#78?fork=shanghai
    #[inline(always)]
    fn exec_push25(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 25)
    }


    /// 0x79 - PUSH26 operation
    /// # Specification: https://www.evm.codes/#79?fork=shanghai
    #[inline(always)]
    fn exec_push26(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 26)
    }


    /// 0x7A - PUSH27 operation
    /// # Specification: https://www.evm.codes/#7a?fork=shanghai
    #[inline(always)]
    fn exec_push27(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 27)
    }

    /// 0x7B - PUSH28 operation
    /// # Specification: https://www.evm.codes/#7b?fork=shanghai
    #[inline(always)]
    fn exec_push28(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 28)
    }


    /// 0x7C - PUSH29 operation
    /// # Specification: https://www.evm.codes/#7c?fork=shanghai
    #[inline(always)]
    fn exec_push29(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 29)
    }


    /// 0x7D - PUSH30 operation
    /// # Specification: https://www.evm.codes/#7d?fork=shanghai
    #[inline(always)]
    fn exec_push30(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 30)
    }


    /// 0x7E - PUSH31 operation
    /// # Specification: https://www.evm.codes/#7e?fork=shanghai
    #[inline(always)]
    fn exec_push31(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 31)
    }


    /// 0x7F - PUSH32 operation
    /// # Specification: https://www.evm.codes/#7f?fork=shanghai
    #[inline(always)]
    fn exec_push32(ref self: VM) -> Result<(), EVMError> {
        exec_push_i(ref self, 32)
    }
}

#[cfg(test)]
mod tests {
    use crate::gas;
    use crate::instructions::PushOperationsTrait;
    use crate::model::vm::VMTrait;
    use crate::stack::StackTrait;
    use crate::test_utils::{VMBuilderTrait};
    use super::exec_push_i;

    #[test]
    fn test_exec_push_i() {
        // Test cases: (bytes_to_push, bytecode_length, expected_value)
        let test_cases: Span<(u8, u8, u256)> = [
            (1, 1, 0xFF), // Push 1 byte
            (16, 16, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF), // Push 16 bytes
            (
                32, 32, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ), // Push 32 bytes (max)
            (
                32, 16, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000000000
            ), // Push 32 bytes, but only 16 available
            (1, 0, 0), // Push 1 byte, but no bytes available
        ].span();

        for elem in test_cases {
            let (bytes_to_push, bytecode_length, expected_value) = *elem;

            let mut vm = VMBuilderTrait::new_with_presets()
                .with_bytecode(get_n_0xFF(bytecode_length))
                .build();
            let initial_pc = vm.pc();
            let initial_gas = vm.gas_left();

            // Execute exec_push_i
            let result = exec_push_i(ref vm, bytes_to_push);

            assert!(result.is_ok());

            // Check stack
            assert_eq!(vm.stack.len(), 1);
            assert_eq!(vm.stack.peek().unwrap(), expected_value);

            // Check PC increment
            let pc_increment = vm.pc() - initial_pc;
            assert_eq!(pc_increment, bytes_to_push.into());

            // Check gas consumption
            let gas_consumed = initial_gas - vm.gas_left();
            assert_eq!(gas_consumed, gas::VERYLOW);
        }
    }

    /// Get a span of 0xFF bytes of length n preceded by a 0x00 byte
    /// to account for the argument offset in push operations
    fn get_n_0xFF(mut n: u8) -> Span<u8> {
        let mut array: Array<u8> = ArrayTrait::new();
        array.append(0x00);
        for _ in 0..n {
            array.append(0xFF);
        };
        array.span()
    }

    #[test]
    fn test_push0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(0)).build();

        // When
        vm.exec_push0().expect('exec_push0 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }

    #[test]
    fn test_push1() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(1)).build();

        // When
        vm.exec_push1().expect('exec_push1 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFF);
    }

    #[test]
    fn test_push2() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(2)).build();

        // When
        vm.exec_push2().expect('exec_push2 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFF);
    }

    #[test]
    fn test_push3() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(3)).build();

        // When
        vm.exec_push3().expect('exec_push3 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFF);
    }

    #[test]
    fn test_push4() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(4)).build();

        // When
        vm.exec_push4().expect('exec_push4 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFF);
    }

    #[test]
    fn test_push5() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(5)).build();

        // When
        vm.exec_push5().expect('exec_push5 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFF);
    }

    #[test]
    fn test_push6() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(6)).build();

        // When
        vm.exec_push6().expect('exec_push6 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFF);
    }

    #[test]
    fn test_push7() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(7)).build();

        // When
        vm.exec_push7().expect('exec_push7 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFF);
    }


    #[test]
    fn test_push8() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(8)).build();

        // When
        vm.exec_push8().expect('exec_push8 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push9() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(9)).build();

        // When
        vm.exec_push9().expect('exec_push9 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push10() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(10)).build();

        // When
        vm.exec_push10().expect('exec_push10 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push11() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(11)).build();

        // When
        vm.exec_push11().expect('exec_push11 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push12() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(12)).build();

        // When
        vm.exec_push12().expect('exec_push12 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push13() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(13)).build();

        // When
        vm.exec_push13().expect('exec_push13 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push14() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(14)).build();

        // When
        vm.exec_push14().expect('exec_push14 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push15() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(15)).build();

        // When
        vm.exec_push15().expect('exec_push15 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push16() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(16)).build();

        // When
        vm.exec_push16().expect('exec_push16 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push17() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(17)).build();

        // When
        vm.exec_push17().expect('exec_push17 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push18() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(18)).build();

        // When
        vm.exec_push18().expect('exec_push18 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }
    #[test]
    fn test_push19() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(19)).build();

        // When
        vm.exec_push19().expect('exec_push19 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push20() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(20)).build();

        // When
        vm.exec_push20().expect('exec_push20 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push21() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(21)).build();

        // When
        vm.exec_push21().expect('exec_push21 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push22() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(22)).build();

        // When
        vm.exec_push22().expect('exec_push22 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }
    #[test]
    fn test_push23() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(23)).build();

        // When
        vm.exec_push23().expect('exec_push23 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }
    #[test]
    fn test_push24() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(24)).build();

        // When
        vm.exec_push24().expect('exec_push24 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push25() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(25)).build();

        // When
        vm.exec_push25().expect('exec_push25 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_push26() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(26)).build();

        // When
        vm.exec_push26().expect('exec_push26 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(
            vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
    }

    #[test]
    fn test_push27() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(27)).build();

        // When
        vm.exec_push27().expect('exec_push27 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(
            vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
    }

    #[test]
    fn test_push28() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(28)).build();

        // When
        vm.exec_push28().expect('exec_push28 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(
            vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
    }

    #[test]
    fn test_push29() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(29)).build();

        // When
        vm.exec_push29().expect('exec_push29 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(
            vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
    }

    #[test]
    fn test_push30() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(30)).build();

        // When
        vm.exec_push30().expect('exec_push30 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(
            vm.stack.peek().unwrap(), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
    }

    #[test]
    fn test_push31() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(31)).build();

        // When
        vm.exec_push31().expect('exec_push31 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(
            vm.stack.peek().unwrap(),
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
    }

    #[test]
    fn test_push32() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(32)).build();

        // When
        vm.exec_push32().expect('exec_push32 failed');
        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(
            vm.stack.peek().unwrap(),
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
    }
}
