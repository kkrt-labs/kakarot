use core::cmp::min;
use core::dict::{Felt252Dict, Felt252DictTrait};
use core::num::traits::{SaturatingSub, CheckedSub};
use core::starknet::EthAddress;
use crate::errors::EVMError;
use crate::memory::Memory;
use crate::model::{Message, Environment, ExecutionResultStatus, ExecutionResult, AccountTrait};
use crate::stack::Stack;
use utils::set::{Set, SetTrait, SpanSet, SpanSetTrait};
use utils::traits::{SpanDefault};

#[derive(Default, Destruct)]
pub struct VM {
    pub stack: Stack,
    pub memory: Memory,
    pub pc: usize,
    pub valid_jumpdests: Felt252Dict<bool>,
    pub return_data: Span<u8>,
    pub env: Environment,
    pub message: Message,
    pub gas_left: u64,
    pub running: bool,
    pub error: bool,
    pub accessed_addresses: Set<EthAddress>,
    pub accessed_storage_keys: Set<(EthAddress, u256)>,
    pub gas_refund: u64
}


#[generate_trait]
pub impl VMImpl of VMTrait {
    #[inline(always)]
    fn new(message: Message, env: Environment) -> VM {
        VM {
            stack: Default::default(),
            memory: Default::default(),
            pc: 0,
            valid_jumpdests: AccountTrait::get_jumpdests(message.code),
            return_data: [].span(),
            env,
            message,
            gas_left: message.gas_limit,
            running: true,
            error: false,
            accessed_addresses: message.accessed_addresses.clone_set(),
            accessed_storage_keys: message.accessed_storage_keys.clone_set(),
            gas_refund: 0
        }
    }

    /// Decrements the gas_left field of the current vm by the value amount.
    /// # Error : returns `EVMError::OutOfGas` if gas_left - value < 0
    #[inline(always)]
    fn charge_gas(ref self: VM, value: u64) -> Result<(), EVMError> {
        self.gas_left = match self.gas_left.checked_sub(value) {
            Option::Some(gas_left) => gas_left,
            Option::None => { return Result::Err(EVMError::OutOfGas); },
        };
        Result::Ok(())
    }


    #[inline(always)]
    fn pc(self: @VM) -> usize {
        *self.pc
    }

    #[inline(always)]
    fn set_pc(ref self: VM, pc: usize) {
        self.pc = pc;
    }

    #[inline(always)]
    fn is_valid_jump(ref self: VM, dest: u32) -> bool {
        self.valid_jumpdests.get(dest.into())
    }

    #[inline(always)]
    fn return_data(self: @VM) -> Span<u8> {
        *self.return_data
    }

    #[inline(always)]
    fn set_return_data(ref self: VM, return_data: Span<u8>) {
        self.return_data = return_data;
    }

    #[inline(always)]
    fn is_running(self: @VM) -> bool {
        *self.running
    }

    #[inline(always)]
    fn stop(ref self: VM) {
        self.running = false;
    }

    #[inline(always)]
    fn set_error(ref self: VM) {
        self.error = true;
    }

    #[inline(always)]
    fn is_error(self: @VM) -> bool {
        *self.error
    }

    #[inline(always)]
    fn message(self: @VM) -> Message {
        *self.message
    }

    #[inline(always)]
    fn gas_left(self: @VM) -> u64 {
        *self.gas_left
    }

    #[inline(always)]
    fn gas_refund(self: @VM) -> u64 {
        *self.gas_refund
    }

    #[inline(always)]
    fn accessed_addresses(self: @VM) -> SpanSet<EthAddress> {
        self.accessed_addresses.spanset()
    }

    #[inline(always)]
    fn accessed_storage_keys(self: @VM) -> SpanSet<(EthAddress, u256)> {
        self.accessed_storage_keys.spanset()
    }

    /// Reads and returns data from bytecode starting at the provided pc.
    ///
    /// # Arguments
    ///
    /// * `self` - The `VM` instance to read the data from.
    /// * `pc` - The starting position in the bytecode to read from.
    /// * `len` - The length of the data to read from the bytecode.
    ///
    /// # Returns
    ///
    /// * A `Span<u8>` containing the requested bytecode slice.
    /// * If the requested slice extends beyond the code length, returns remaining bytes.
    #[inline(always)]
    fn read_code(self: @VM, pc: usize, len: usize) -> Span<u8> {
        let code_len = self.message().code.len();

        // If pc is out of bounds, return an empty span
        if pc >= code_len {
            return [].span();
        }

        // Calculate the actual length to read
        let remaining = code_len.saturating_sub(pc);
        let actual_len = min(len, remaining);

        // Return the slice with the actual length
        self.message().code.slice(pc, actual_len)
    }

    #[inline(always)]
    fn merge_child(ref self: VM, child: @ExecutionResult) {
        match child.status {
            ExecutionResultStatus::Success => {
                self.accessed_addresses.extend(*child.accessed_addresses);
                self.accessed_storage_keys.extend(*child.accessed_storage_keys);
                self.gas_refund += *child.gas_refund;
                self.gas_left += *child.gas_left;
                self.return_data = *child.return_data;
            },
            ExecutionResultStatus::Revert => { self.gas_left += *child.gas_left; },
            // If the call has halted exceptionnaly, the gas is not returned.
            ExecutionResultStatus::Exception => {}
        };
    }
}

#[cfg(test)]
mod tests {
    use crate::errors::EVMError;
    use crate::model::Message;
    use crate::model::vm::VMTrait;
    use crate::test_utils::{tx_gas_limit, VMBuilderTrait};

    #[test]
    fn test_vm_default() {
        let mut vm = VMTrait::new(Default::default(), Default::default());

        assert!(vm.pc() == 0);
        assert!(vm.is_running());
        assert!(!vm.error);
        assert_eq!(vm.gas_left(), vm.message().gas_limit);
    }


    #[test]
    fn test_set_pc() {
        let mut vm = VMTrait::new(Default::default(), Default::default());

        let new_pc = 42;
        vm.set_pc(new_pc);

        assert(vm.pc() == new_pc, 'wrong pc');
    }

    #[test]
    fn test_error() {
        let mut vm = VMTrait::new(Default::default(), Default::default());

        vm.set_error();

        assert!(vm.error);
    }

    #[test]
    fn test_increment_gas_checked() {
        let mut vm = VMTrait::new(Default::default(), Default::default());

        assert_eq!(vm.gas_left(), vm.message().gas_limit);

        let result = vm.charge_gas(tx_gas_limit());

        assert_eq!(result.unwrap_err(), EVMError::OutOfGas);
    }

    #[test]
    fn test_set_stopped() {
        let mut vm = VMTrait::new(Default::default(), Default::default());

        vm.stop();

        assert!(!vm.is_running())
    }

    #[test]
    fn test_read_code_within_bounds() {
        let bytecode = [0x01, 0x02, 0x03, 0x04, 0x05].span();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        vm.set_pc(1);

        let read_code = vm.read_code(vm.pc(), 3);

        assert_eq!(read_code, [0x02, 0x03, 0x04].span());
        assert_eq!(vm.pc(), 1);
    }

    #[test]
    fn test_read_code_out_of_bounds() {
        let bytecode = [0x01, 0x02, 0x03].span();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        vm.set_pc(2);

        let read_code = vm.read_code(vm.pc(), 3);

        assert_eq!(read_code, [0x03].span());
        assert_eq!(vm.pc(), 2);
    }

    #[test]
    fn test_read_code_at_boundary() {
        let bytecode = [0x01, 0x02, 0x03, 0x04, 0x05].span();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        vm.set_pc(3);

        let read_code = vm.read_code(vm.pc(), 3);

        assert_eq!(read_code, [0x04, 0x05].span());
        assert_eq!(vm.pc(), 3);
    }

    #[test]
    fn test_set_return() {
        let mut vm = VMTrait::new(Default::default(), Default::default());
        vm.set_return_data([0x01, 0x02, 0x03].span());
        let return_data = vm.return_data();
        assert(return_data == [0x01, 0x02, 0x03].span(), 'wrong return data');
    }

    #[test]
    fn test_return_data() {
        let mut vm = VMTrait::new(Default::default(), Default::default());

        let return_data = vm.return_data();
        assert(return_data.len() == 0, 'wrong length');
    }

    #[test]
    fn test_is_valid_jump_destinations() {
        // PUSH1, 0x03, JUMP, JUMPDEST, PUSH1, 0x09, JUMP, PUSH1 0x2, JUMPDDEST, PUSH1 0x2
        let mut message: Message = Default::default();
        message.code = [0x60, 0x3, 0x56, 0x5b, 0x60, 0x9, 0x56, 0x60, 0x2, 0x5b, 0x60, 0x2].span();

        let mut vm = VMTrait::new(message, Default::default());

        assert!(vm.is_valid_jump(0x3), "expected jump to be valid");
        assert!(vm.is_valid_jump(0x9), "expected jump to be valid");

        assert!(!vm.is_valid_jump(0x4), "expected jump to be invalid");
        assert!(!vm.is_valid_jump(0x5), "expected jump to be invalid");
    }

    #[test]
    fn test_valid_jump_destination_inside_jumpn() {
        let mut message: Message = Default::default();
        message.code = [0x60, 0x5B, 0x60, 0x00].span();

        let mut vm = VMTrait::new(message, Default::default());
        assert!(!vm.is_valid_jump(0x1), "expected false");
    }
}
