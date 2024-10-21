//! Exchange Operations.

use crate::errors::EVMError;
use crate::gas;
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;

/// Place i bytes items on stack.
#[inline(always)]
fn exec_swap_i(ref self: VM, i: u8) -> Result<(), EVMError> {
    self.charge_gas(gas::VERYLOW)?;
    self.stack.swap_i(i.into())
}

#[generate_trait]
pub impl ExchangeOperations of ExchangeOperationsTrait {
    /// 0x90 - SWAP1 operation
    /// Exchange 1st and 2nd stack items.
    /// # Specification: https://www.evm.codes/#90?fork=shanghai

    fn exec_swap1(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 1)
    }

    /// 0x91 - SWAP2 operation
    /// Exchange 1st and 3rd stack items.
    /// # Specification: https://www.evm.codes/#91?fork=shanghai
    fn exec_swap2(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 2)
    }

    /// 0x92 - SWAP3 operation
    /// Exchange 1st and 4th stack items.
    /// # Specification: https://www.evm.codes/#92?fork=shanghai
    fn exec_swap3(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 3)
    }

    /// 0x93 - SWAP4 operation
    /// Exchange 1st and 5th stack items.
    /// # Specification: https://www.evm.codes/#93?fork=shanghai
    fn exec_swap4(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 4)
    }

    /// 0x94 - SWAP5 operation
    /// Exchange 1st and 6th stack items.
    /// # Specification: https://www.evm.codes/#94?fork=shanghai
    fn exec_swap5(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 5)
    }

    /// 0x95 - SWAP6 operation
    /// Exchange 1st and 7th stack items.
    /// # Specification: https://www.evm.codes/#95?fork=shanghai
    fn exec_swap6(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 6)
    }

    /// 0x96 - SWAP7 operation
    /// Exchange 1st and 8th stack items.
    /// # Specification: https://www.evm.codes/#96?fork=shanghai
    fn exec_swap7(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 7)
    }

    /// 0x97 - SWAP8 operation
    /// Exchange 1st and 9th stack items.
    /// # Specification: https://www.evm.codes/#97?fork=shanghai
    fn exec_swap8(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 8)
    }

    /// 0x98 - SWAP9 operation
    /// Exchange 1st and 10th stack items.
    /// # Specification: https://www.evm.codes/#98?fork=shanghai
    fn exec_swap9(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 9)
    }

    /// 0x99 - SWAP10 operation
    /// Exchange 1st and 11th stack items.
    /// # Specification: https://www.evm.codes/#99?fork=shanghai
    fn exec_swap10(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 10)
    }

    /// 0x9A - SWAP11 operation
    /// Exchange 1st and 12th stack items.
    /// # Specification: https://www.evm.codes/#9a?fork=shanghai
    fn exec_swap11(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 11)
    }

    /// 0x9B - SWAP12 operation
    /// Exchange 1st and 13th stack items.
    /// # Specification: https://www.evm.codes/#9b?fork=shanghai
    fn exec_swap12(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 12)
    }

    /// 0x9C - SWAP13 operation
    /// Exchange 1st and 14th stack items.
    /// # Specification: https://www.evm.codes/#9c?fork=shanghai
    fn exec_swap13(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 13)
    }

    /// 0x9D - SWAP14 operation
    /// Exchange 1st and 15th stack items.
    /// # Specification: https://www.evm.codes/#9d?fork=shanghai
    fn exec_swap14(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 14)
    }

    /// 0x9E - SWAP15 operation
    /// Exchange 1st and 16th stack items.
    /// # Specification: https://www.evm.codes/#9e?fork=shanghai
    fn exec_swap15(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 15)
    }

    /// 0x9F - SWAP16 operation
    /// Exchange 1st and 16th stack items.
    /// # Specification: https://www.evm.codes/#9f?fork=shanghai
    fn exec_swap16(ref self: VM) -> Result<(), EVMError> {
        exec_swap_i(ref self, 16)
    }
}


#[cfg(test)]
mod tests {
    use crate::instructions::exchange_operations::ExchangeOperationsTrait;
    use crate::stack::StackTrait;
    use crate::test_utils::VMBuilderTrait;


    #[test]
    fn test_exec_swap1() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap1().expect('exec_swap1 failed');

        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
        assert(vm.stack.peek_at(1).unwrap() == 1, 'val at index 1 should be now 1');
    }


    #[test]
    fn test_exec_swap2() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap2().expect('exec_swap2 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
        assert(vm.stack.peek_at(2).unwrap() == 1, 'val at index 2 should be now 1');
    }

    #[test]
    fn test_exec_swap3() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap3().expect('exec_swap3 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
        assert(vm.stack.peek_at(3).unwrap() == 1, 'val at index 3 should be now 1');
    }

    #[test]
    fn test_exec_swap4() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap4().expect('exec_swap4 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(4).unwrap() == 1, 'val at index 4 should be now 1');
    }


    #[test]
    fn test_exec_swap5() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap5().expect('exec_swap5 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(5).unwrap() == 1, 'val at index 5 should be now 1');
    }

    #[test]
    fn test_exec_swap6() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap6().expect('exec_swap6 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(6).unwrap() == 1, 'val at index 6 should be now 1');
    }


    #[test]
    fn test_exec_swap7() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap7().expect('exec_swap7 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(7).unwrap() == 1, 'val at index 7 should be now 1');
    }

    #[test]
    fn test_exec_swap8() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap8().expect('exec_swap8 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(8).unwrap() == 1, 'val at index 8 should be now 1');
    }


    #[test]
    fn test_exec_swap9() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap9().expect('exec_swap9 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(9).unwrap() == 1, 'val at index 9 should be now 1');
    }

    #[test]
    fn test_exec_swap10() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap10().expect('exec_swap10 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(10).unwrap() == 1, 'val at index 10 should be now 1');
    }

    #[test]
    fn test_exec_swap11() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap11().expect('exec_swap11 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(11).unwrap() == 1, 'val at index 11 should be now 1');
    }

    #[test]
    fn test_exec_swap12() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap12().expect('exec_swap12 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(12).unwrap() == 1, 'val at index 12 should be now 1');
    }

    #[test]
    fn test_exec_swap13() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap13().expect('exec_swap13 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(13).unwrap() == 1, 'val at index 13 should be now 1');
    }

    #[test]
    fn test_exec_swap14() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap14().expect('exec_swap14 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(14).unwrap() == 1, 'val at index 14 should be now 1');
    }

    #[test]
    fn test_exec_swap15() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap15().expect('exec_swap15 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(15).unwrap() == 1, 'val at index 15 should be now 1');
    }

    #[test]
    fn test_exec_swap16() {
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // given
        vm.stack.push(0xf).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');
        vm.exec_swap16().expect('exec_swap16 failed');
        assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
        assert(vm.stack.peek_at(16).unwrap() == 1, 'val at index 16 should be now 1');
    }
}
