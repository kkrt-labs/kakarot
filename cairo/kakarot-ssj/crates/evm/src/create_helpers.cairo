use core::num::traits::Bounded;
use core::num::traits::Zero;
use core::starknet::EthAddress;
use crate::errors::{ensure, EVMError};
use crate::gas;
use crate::interpreter::EVMTrait;
use crate::memory::MemoryTrait;
use crate::model::Message;
use crate::model::account::{Account, AccountTrait};
use crate::model::vm::{VM, VMTrait};
use crate::model::{ExecutionResult, ExecutionResultTrait, ExecutionResultStatus};
use crate::stack::StackTrait;
use crate::state::StateTrait;
use utils::address::{compute_contract_address, compute_create2_contract_address};
use utils::constants;
use utils::helpers::bytes_32_words_size;
use utils::set::SetTrait;
use utils::traits::{
    BoolIntoNumeric, EthAddressIntoU256, U256TryIntoResult, SpanU8TryIntoResultEthAddress
};

/// Helper struct to prepare CREATE and CREATE2 opcodes
#[derive(Drop)]
pub struct CreateArgs {
    to: EthAddress,
    value: u256,
    bytecode: Span<u8>,
}

#[derive(Copy, Drop)]
pub enum CreateType {
    Create,
    Create2,
}

#[generate_trait]
pub impl CreateHelpersImpl of CreateHelpers {
    ///  Prepare the initialization of a new child or so-called sub-context
    /// As part of the CREATE family of opcodes.
    fn prepare_create(ref self: VM, create_type: CreateType) -> Result<CreateArgs, EVMError> {
        let value = self.stack.pop()?;
        let offset = self.stack.pop_saturating_usize()?;
        let size = self.stack.pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, size)].span())?;
        self.memory.ensure_length(memory_expansion.new_size);
        let init_code_gas = gas::init_code_cost(size);
        let charged_gas = match create_type {
            CreateType::Create => gas::CREATE + memory_expansion.expansion_cost + init_code_gas,
            CreateType::Create2 => {
                let calldata_words = bytes_32_words_size(size);
                gas::CREATE
                    + gas::KECCAK256WORD * calldata_words.into()
                    + memory_expansion.expansion_cost
                    + init_code_gas
            },
        };
        self.charge_gas(charged_gas)?;

        let mut bytecode = Default::default();
        self.memory.load_n(size, ref bytecode, offset);

        let to = match create_type {
            CreateType::Create => {
                let nonce = self.env.state.get_account(self.message().target.evm).nonce();
                compute_contract_address(self.message().target.evm, sender_nonce: nonce)
            },
            CreateType::Create2 => compute_create2_contract_address(
                self.message().target.evm, salt: self.stack.pop()?, bytecode: bytecode.span()
            )?,
        };

        Result::Ok(CreateArgs { to, value, bytecode: bytecode.span() })
    }


    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn generic_create(ref self: VM, create_args: CreateArgs) -> Result<(), EVMError> {
        self.accessed_addresses.add(create_args.to);

        let create_message_gas = gas::max_message_call_gas(self.gas_left);
        self.gas_left -= create_message_gas;

        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;
        self.return_data = [].span();

        // The sender in the subcontext is the message's target
        let sender_address = self.message().target;
        let mut sender = self.env.state.get_account(sender_address.evm);
        let sender_current_nonce = sender.nonce();
        if sender.balance() < create_args.value
            || sender_current_nonce == Bounded::<u64>::MAX
            || self.message.depth == constants::STACK_MAX_DEPTH {
            self.gas_left += create_message_gas;
            return self.stack.push(0);
        }

        sender
            .set_nonce(
                sender_current_nonce + 1
            ); // Will not overflow because of the previous check.
        self.env.state.set_account(sender);

        let mut target_account = self.env.state.get_account(create_args.to);
        let target_address = target_account.address();
        // Collision happens if the target account loaded in state has code or nonce set, meaning
        // - it's deployed on SN and is an active EVM contract
        // - it's not deployed on SN and is an active EVM contract in the Kakarot cache
        if target_account.has_code_or_nonce() {
            return self.stack.push(0);
        };

        ensure(create_args.bytecode.len() <= constants::MAX_INITCODE_SIZE, EVMError::OutOfGas)?;

        let child_message = Message {
            caller: sender_address,
            target: target_address,
            gas_limit: create_message_gas,
            data: [].span(),
            code: create_args.bytecode,
            code_address: Zero::zero(),
            value: create_args.value,
            should_transfer_value: true,
            depth: self.message().depth + 1,
            read_only: false,
            accessed_addresses: self.accessed_addresses.clone().spanset(),
            accessed_storage_keys: self.accessed_storage_keys.clone().spanset(),
        };

        let result = EVMTrait::process_create_message(child_message, ref self.env);
        self.merge_child(@result);

        match result.status {
            ExecutionResultStatus::Success => {
                self.return_data = [].span();
                self.stack.push(target_address.evm.into())?;
            },
            ExecutionResultStatus::Revert => {
                self.return_data = result.return_data;
                self.stack.push(0)?;
            },
            ExecutionResultStatus::Exception => {
                // returndata is emptied in case of exception
                self.return_data = [].span();
                self.stack.push(0)?;
            },
        }
        Result::Ok(())
    }

    /// Finalizes the creation of an account contract by
    /// setting its code and charging the gas for the code deposit.
    /// Since we don't have access to the child vm anymore, we charge the gas on
    /// the returned ExecutionResult of the childVM.
    ///
    /// # Arguments
    /// * `self` - The ExecutionResult to charge the gas on.
    /// * `account` - The Account to finalize
    #[inline(always)]
    fn finalize_creation(
        ref self: ExecutionResult, mut account: Account
    ) -> Result<Account, EVMError> {
        let code = self.return_data;
        let contract_code_gas = code.len().into() * gas::CODEDEPOSIT;

        if code.len() != 0 {
            ensure(*code[0] != 0xEF, EVMError::InvalidCode)?;
        }
        self.charge_gas(contract_code_gas)?;

        ensure(code.len() <= constants::MAX_CODE_SIZE, EVMError::OutOfGas)?;

        account.set_code(code);
        Result::Ok(account)
    }
}

#[cfg(test)]
mod tests {
    //TODO: test create helpers


}
