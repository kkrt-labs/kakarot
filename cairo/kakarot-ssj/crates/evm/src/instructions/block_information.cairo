//! Block Information.

use core::num::traits::SaturatingAdd;
use core::starknet::SyscallResultTrait;
use core::starknet::syscalls::get_block_hash_syscall;

use crate::errors::EVMError;

use crate::gas;
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;
use crate::state::StateTrait;
use utils::constants::MIN_BASE_FEE_PER_BLOB_GAS;
use utils::traits::{EthAddressTryIntoResultContractAddress, EthAddressIntoU256};

#[generate_trait]
pub impl BlockInformation of BlockInformationTrait {
    /// 0x40 - BLOCKHASH
    /// Get the hash of one of the 256 most recent complete blocks.
    /// # Specification: https://www.evm.codes/#40?fork=shanghai
    fn exec_blockhash(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BLOCKHASH)?;

        // Saturate to MAX_U64 to avoid a revert when the hash requested is too big. It should just
        // push 0.
        let block_number = self.stack.pop_saturating_u64()?;
        let current_block = self.env.block_number;

        // If input block number is lower than current_block - 256, return 0
        // If input block number is higher than current_block - 10, return 0
        // Note: in the specs, input block number can be equal - at most - to the current block
        // number minus one.
        // In Starknet, the `get_block_hash_syscall` is capped at current block minus ten.
        // TODO: monitor the changes in the `get_block_hash_syscall` syscall.
        // source:
        // https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/system-calls-cairo1/#get_block_hash
        if block_number.saturating_add(10) > current_block
            || block_number.saturating_add(256) < current_block {
            return self.stack.push(0);
        }

        self.stack.push(get_block_hash_syscall(block_number).unwrap_syscall().into())
    }

    /// 0x41 - COINBASE
    /// Get the block's beneficiary address.
    /// # Specification: https://www.evm.codes/#41?fork=shanghai
    fn exec_coinbase(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let coinbase = self.env.coinbase;
        self.stack.push(coinbase.into())
    }

    /// 0x42 - TIMESTAMP
    /// Get the block’s timestamp
    /// # Specification: https://www.evm.codes/#42?fork=shanghai
    fn exec_timestamp(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_timestamp.into())
    }

    /// 0x43 - NUMBER
    /// Get the block number.
    /// # Specification: https://www.evm.codes/#43?fork=shanghai
    fn exec_number(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_number.into())
    }

    /// 0x44 - PREVRANDAO
    /// # Specification: https://www.evm.codes/#44?fork=shanghai
    fn exec_prevrandao(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.prevrandao)
    }

    /// 0x45 - GASLIMIT
    /// Get the block’s gas limit
    /// # Specification: https://www.evm.codes/#45?fork=shanghai
    fn exec_gaslimit(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_gas_limit.into())
    }

    /// 0x46 - CHAINID
    /// Get the chain ID.
    /// # Specification: https://www.evm.codes/#46?fork=shanghai
    fn exec_chainid(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let chain_id = self.env.chain_id;
        self.stack.push(chain_id.into())
    }

    /// 0x47 - SELFBALANCE
    /// Get balance of currently executing contract
    /// # Specification: https://www.evm.codes/#47?fork=shanghai
    fn exec_selfbalance(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;

        let evm_address = self.message().target.evm;

        let balance = self.env.state.get_account(evm_address).balance;

        self.stack.push(balance)
    }

    /// 0x48 - BASEFEE
    /// Get base fee.
    /// # Specification: https://www.evm.codes/#48?fork=shanghai
    fn exec_basefee(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.base_fee.into())
    }

    /// 0x49 - BLOBHASH
    /// Returns the value of the blob hash of the current block
    /// Always returns Zero in the context of Kakarot
    /// # Specification: https://www.evm.codes/#49?fork=cancun
    fn exec_blobhash(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BLOB_HASH_COST)?;

        self.stack.push(0)
    }

    /// 0x4A - BLOBBASEFEE
    /// Returns the value of the blob base-fee of the current block
    /// Always returns Zero in the context of Kakarot
    /// # Specification: https://www.evm.codes/#4a?fork=cancun
    fn exec_blobbasefee(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(MIN_BASE_FEE_PER_BLOB_GAS.into())
    }
}


#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use crate::instructions::BlockInformationTrait;
    use crate::model::account::Account;
    use crate::model::vm::VMTrait;
    use crate::stack::StackTrait;
    use crate::state::StateTrait;
    use crate::test_utils::{VMBuilderTrait, gas_price, setup_test_environment};
    use snforge_std::{start_cheat_block_number_global, start_cheat_block_timestamp_global};
    use utils::constants::EMPTY_KECCAK;
    use utils::constants;
    use utils::traits::{EthAddressIntoU256};


    /// 0x40 - BLOCKHASH
    #[test]
    fn test_exec_blockhash_below_bounds() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        start_cheat_block_number_global(500);

        // When
        vm.stack.push(243).expect('push failed');
        vm.exec_blockhash().unwrap();

        // Then
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    #[test]
    fn test_exec_blockhash_above_bounds() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        start_cheat_block_number_global(500);

        // When
        vm.stack.push(491).expect('push failed');
        vm.exec_blockhash().unwrap();

        // Then
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    // TODO: implement exec_blockhash testing for block number within bounds
    //TODO(sn-foundry): mock the block hash
    // https://github.com/starkware-libs/cairo/blob/77a7e7bc36aa1c317bb8dd5f6f7a7e6eef0ab4f3/crates/cairo-lang-starknet/cairo_level_tests/interoperability.cairo#L173
    #[test]
    #[ignore]
    fn test_exec_blockhash_within_bounds() {
        // If not set the default block number is 0.
        let queried_block = 244;
        start_cheat_block_number_global(500);
        //TODO: restore start_cheat_block_hash_global(queried_block, 0xF);

        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.stack.push(queried_block.into()).expect('push failed');
        vm.exec_blockhash().expect('exec failed');
        //TODO the CASM runner used in tests doesn't implement
        //`get_block_hash_syscall` yet. As such, this test should fail no if the
        //queried block is within bounds
        // Then
        assert(vm.stack.peek().unwrap() == 0xF, 'stack top should be 0xF');
    }


    #[test]
    fn test_block_timestamp_set_to_1692873993() {
        // 24/08/2023 12h46 33s
        // If not set the default timestamp is 0.
        start_cheat_block_timestamp_global(1692873993);

        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_timestamp().unwrap();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 1692873993, 'stack top should be 1692873993');
    }

    #[test]
    fn test_block_number_set_to_32() {
        // If not set the default block number is 0.
        start_cheat_block_number_global(32);

        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_number().unwrap();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 32, 'stack top should be 32');
    }

    #[test]
    fn test_gaslimit() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_gaslimit().unwrap();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        // This value is set in [new_with_presets].
        assert_eq!(vm.stack.peek().unwrap(), constants::BLOCK_GAS_LIMIT.into())
    }

    // *************************************************************************
    // 0x47: SELFBALANCE
    // *************************************************************************
    #[test]
    fn test_exec_selfbalance_should_push_balance() {
        // Given
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 400,
            nonce: 0,
            code: [].span(),
            code_hash: EMPTY_KECCAK,
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);

        // When
        vm.exec_selfbalance().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 400);
    }


    #[test]
    fn test_basefee_should_push_env_base_fee() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_basefee().unwrap();

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), vm.env.base_fee.into());
    }

    #[test]
    fn test_chainid_should_push_chain_id_to_stack() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_chainid().unwrap();

        // Then
        let chain_id = vm.stack.peek().unwrap();
        assert(vm.env.chain_id.into() == chain_id, 'stack should have chain id');
    }


    #[test]
    fn test_randao_should_push_zero_to_stack() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_prevrandao().unwrap();

        // Then
        let result = vm.stack.peek().unwrap();
        assert(result == 0x00, 'stack top should be zero');
    }

    #[test]
    fn test_blobhash_should_return_zero() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_blobhash().unwrap();

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }


    #[test]
    fn test_blobbasefee_should_return_one() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_blobbasefee().unwrap();

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), 1);
    }


    // *************************************************************************
    // 0x41: COINBASE
    // *************************************************************************
    #[test]
    fn test_exec_coinbase() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_coinbase().unwrap();

        // Then
        let coinbase_address = vm.stack.peek().unwrap();
        assert(vm.env.coinbase.into() == coinbase_address, 'wrong coinbase address');
    }
}
