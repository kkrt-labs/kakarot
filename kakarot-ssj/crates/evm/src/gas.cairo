use core::cmp::min;
use core::num::traits::CheckedAdd;
use crate::errors::EVMError;
use utils::eth_transaction::common::TxKindTrait;
use utils::eth_transaction::eip2930::{AccessListItem};
use utils::eth_transaction::transaction::{Transaction, TransactionTrait};
use utils::helpers;

//! Gas costs for EVM operations
//! Code is based on alloy project
//! Source: <https://github.com/bluealloy/revm/blob/main/crates/interpreter/src/gas/constants.rs>

pub const ZERO: u64 = 0;
pub const BASE: u64 = 2;
pub const VERYLOW: u64 = 3;
pub const LOW: u64 = 5;
pub const MID: u64 = 8;
pub const HIGH: u64 = 10;
pub const JUMPDEST: u64 = 1;
pub const SELFDESTRUCT: u64 = 5000;
pub const CREATE: u64 = 32000;
pub const CALLVALUE: u64 = 9000;
pub const NEWACCOUNT: u64 = 25000;
pub const EXP: u64 = 10;
pub const EXP_GAS_PER_BYTE: u64 = 50;
pub const MEMORY: u64 = 3;
pub const LOG: u64 = 375;
pub const LOGDATA: u64 = 8;
pub const LOGTOPIC: u64 = 375;
pub const KECCAK256: u64 = 30;
pub const KECCAK256WORD: u64 = 6;
pub const COPY: u64 = 3;
pub const BLOCKHASH: u64 = 20;
pub const CODEDEPOSIT: u64 = 200;

pub const SSTORE_SET: u64 = 20000;
pub const SSTORE_RESET: u64 = 5000;
pub const REFUND_SSTORE_CLEARS: u64 = 4800;

pub const TRANSACTION_ZERO_DATA: u64 = 4;
pub const TRANSACTION_NON_ZERO_DATA_INIT: u64 = 16;
pub const TRANSACTION_NON_ZERO_DATA_FRONTIER: u64 = 68;
pub const TRANSACTION_BASE_COST: u64 = 21000;
pub const TRANSACTION_CREATE_COST: u64 = 32000;

// Berlin EIP-2929 constants
pub const ACCESS_LIST_ADDRESS: u64 = 2400;
pub const ACCESS_LIST_STORAGE_KEY: u64 = 1900;
pub const COLD_SLOAD_COST: u64 = 2100;
pub const COLD_ACCOUNT_ACCESS_COST: u64 = 2600;
pub const WARM_ACCESS_COST: u64 = 100;

/// EIP-3860 : Limit and meter initcode
pub const INITCODE_WORD_COST: u64 = 2;

pub const CALL_STIPEND: u64 = 2300;

// EIP-4844
pub const BLOB_HASH_COST: u64 = 3;

/// Defines the gas cost and stipend for executing call opcodes.
///
/// # Struct fields
///
/// * `cost`: The non-refundable portion of gas reserved for executing the call opcode.
/// * `stipend`: The portion of gas available to sub-calls that is refundable if not consumed.
#[derive(Drop)]
pub struct MessageCallGas {
    pub cost: u64,
    pub stipend: u64,
}

/// Defines the new size and the expansion cost after memory expansion.
///
/// # Struct fields
///
/// * `new_size`: The new size of the memory after extension.
/// * `expansion_cost`: The cost of the memory extension.
#[derive(Drop)]
pub struct MemoryExpansion {
    pub new_size: u32,
    pub expansion_cost: u64,
}

/// Calculates the maximum gas that is allowed for making a message call.
///
/// # Arguments
/// * `gas`: The gas available for the message call.
///
/// # Returns
/// * The maximum gas allowed for the message call.
pub fn max_message_call_gas(gas: u64) -> u64 {
    gas - (gas / 64)
}

/// Calculates the MessageCallGas (cost and stipend) for executing call Opcodes.
///
/// # Parameters
///
/// * `value`: The amount of native token that needs to be transferred.
/// * `gas`: The amount of gas provided to the message-call.
/// * `gas_left`: The amount of gas left in the current frame.
/// * `memory_cost`: The amount needed to extend the memory in the current frame.
/// * `extra_gas`: The amount of gas needed for transferring value + creating a new account inside a
/// message call.
///
/// # Returns
///
/// * `Result<MessageCallGas, EVMError>`: The calculated MessageCallGas or an error if overflow
/// occurs.
pub fn calculate_message_call_gas(
    value: u256, gas: u64, gas_left: u64, memory_cost: u64, extra_gas: u64
) -> Result<MessageCallGas, EVMError> {
    let call_stipend = if value == 0 {
        0
    } else {
        CALL_STIPEND
    };

    // Check for overflow when adding extra_gas and memory_cost
    let total_extra_cost = extra_gas.checked_add(memory_cost).ok_or(EVMError::OutOfGas)?;
    let gas = if gas_left < total_extra_cost {
        gas
    } else {
        let remaining_gas = gas_left - total_extra_cost; // Safe because of the check above
        min(gas, max_message_call_gas(remaining_gas))
    };

    let cost = gas.checked_add(extra_gas).ok_or(EVMError::OutOfGas)?;
    let stipend = gas.checked_add(call_stipend).ok_or(EVMError::OutOfGas)?;

    Result::Ok(MessageCallGas { cost, stipend })
}


/// Calculates the gas cost for allocating memory
/// to the smallest multiple of 32 bytes,
/// such that the allocated size is at least as big as the given size.
///
/// To optimize computations on u128 and avoid overflows, we compute size_in_words / 512
///  instead of size_in_words * size_in_words / 512. Then we recompute the
///  resulting quotient: x^2 = 512q + r becomes
///  x = 512 q0 + r0 => x^2 = 512(512 q0^2 + 2 q0 r0) + r0^2
///  r0^2 = 512 q1 + r1
///  x^2 = 512(512 q0^2 + 2 q0 r0 + q1) + r1
///  q = 512 * q0 * q0 + 2 * q0 * r0 + q1
/// # Parameters
///
/// * `size_in_bytes` - The size of the data in bytes.
///
/// # Returns
///
/// * `total_gas_cost` - The gas cost for storing data in memory.
pub fn calculate_memory_gas_cost(size_in_bytes: usize) -> u64 {
    let _512: NonZero<u64> = 512_u64.try_into().unwrap();
    let size_in_words = (size_in_bytes + 31) / 32;
    let linear_cost = size_in_words.into() * MEMORY;

    let (q0, r0) = DivRem::div_rem(size_in_words.into(), _512);
    let (q1, _) = DivRem::div_rem(r0 * r0, _512);
    let quadratic_cost = 512 * q0 * q0 + 2 * q0 * r0 + q1;

    linear_cost + quadratic_cost
}


/// Calculates memory expansion based on multiple memory operations.
///
/// # Arguments
///
/// * `current_size`: Current size of the memory.
/// * `operations`: A span of tuples (offset, size) representing memory operations.
///
/// # Returns
///
/// * `MemoryExpansion`: New size and expansion cost.
pub fn memory_expansion(
    current_size: usize, mut operations: Span<(usize, usize)>
) -> Result<MemoryExpansion, EVMError> {
    let mut current_max_size = current_size;

    // Using a high-level loop because Cairo doesn't support the `for` loop syntax with breaks
    let max_size = loop {
        match operations.pop_front() {
            Option::Some((
                offset, size
            )) => {
                if *size != 0 {
                    match (*offset).checked_add(*size) {
                        Option::Some(end) => {
                            if end > current_max_size {
                                current_max_size = end;
                            }
                        },
                        Option::None => { break Result::Err(EVMError::MemoryLimitOOG); },
                    }
                }
            },
            Option::None => { break Result::Ok((current_max_size)); },
        }
    }?;

    let new_size = helpers::bytes_32_words_size(max_size) * 32;

    if new_size <= current_size {
        return Result::Ok(MemoryExpansion { new_size: current_size, expansion_cost: 0 });
    }

    let prev_cost = calculate_memory_gas_cost(current_size);
    let new_cost = calculate_memory_gas_cost(new_size);
    let expansion_cost = new_cost - prev_cost;
    Result::Ok(MemoryExpansion { new_size, expansion_cost })
}

/// Calculates the gas to be charged for the init code in CREATE/CREATE2
/// opcodes as well as create transactions.
///
/// # Arguments
///
/// * `code_size` - The size of the init code
///
/// # Returns
///
/// * `init_code_gas` - The gas to be charged for the init code.
#[inline(always)]
pub fn init_code_cost(code_size: usize) -> u64 {
    let code_size_in_words = helpers::bytes_32_words_size(code_size);
    code_size_in_words.into() * INITCODE_WORD_COST
}

/// Calculates the gas that is charged before execution is started.
///
/// The intrinsic cost of the transaction is charged before execution has
/// begun. Functions/operations in the EVM cost money to execute so this
/// intrinsic cost is for the operations that need to be paid for as part of
/// the transaction. Data transfer, for example, is part of this intrinsic
/// cost. It costs ether to send data over the wire and that ether is
/// accounted for in the intrinsic cost calculated in this function. This
/// intrinsic cost must be calculated and paid for before execution in order
/// for all operations to be implemented.
///
/// Reference:
/// https://github.com/ethereum/execution-specs/blob/master/src/ethereum/shanghai/fork.py#L689
pub fn calculate_intrinsic_gas_cost(tx: @Transaction) -> u64 {
    let mut data_cost: u64 = 0;

    let mut calldata = tx.input();
    let calldata_len: usize = calldata.len();

    for data in calldata {
        data_cost +=
            if *data == 0 {
                TRANSACTION_ZERO_DATA
            } else {
                TRANSACTION_NON_ZERO_DATA_INIT
            };
    };

    let create_cost: u64 = if tx.kind().is_create() {
        TRANSACTION_CREATE_COST + init_code_cost(calldata_len)
    } else {
        0
    };

    let access_list_cost = if let Option::Some(mut access_list) = tx.access_list() {
        let mut access_list_cost: u64 = 0;
        for access_list_item in access_list {
            let AccessListItem { ethereum_address: _, storage_keys } = *access_list_item;
            access_list_cost += ACCESS_LIST_ADDRESS
                + (ACCESS_LIST_STORAGE_KEY * storage_keys.len().into());
        };
        access_list_cost
    } else {
        0
    };

    TRANSACTION_BASE_COST + data_cost + create_cost + access_list_cost
}

#[cfg(test)]
mod tests {
    use core::starknet::EthAddress;

    use crate::gas::{
        calculate_intrinsic_gas_cost, calculate_memory_gas_cost, ACCESS_LIST_ADDRESS,
        ACCESS_LIST_STORAGE_KEY
    };
    use crate::test_utils::evm_address;
    use utils::eth_transaction::eip2930::{AccessListItem, TxEip2930};
    use utils::eth_transaction::legacy::TxLegacy;
    use utils::eth_transaction::transaction::Transaction;
    use utils::traits::bytes::ToBytes;

    #[test]
    fn test_calculate_intrinsic_gas_cost() {
        // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
        // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
        //   16      16      16       16      16      16      16      4        4      16
        //   + 21000
        //   + 0
        //   ---------------------------
        //   = 21136
        let rlp_encoded: u256 = 0xc981f781808184000012;

        let input = rlp_encoded.to_be_bytes();
        let to: EthAddress = 'vitalik.eth'.try_into().unwrap();

        let tx: Transaction = Transaction::Legacy(
            TxLegacy {
                to: to.into(),
                nonce: 0,
                gas_price: 50,
                gas_limit: 433926,
                value: 1,
                input,
                chain_id: Option::Some(0x1)
            }
        );

        let expected_cost: u64 = 21136;
        let out_cost: u64 = calculate_intrinsic_gas_cost(@tx);

        assert_eq!(out_cost, expected_cost, "wrong cost");
    }

    #[test]
    fn test_calculate_intrinsic_gas_cost_with_access_list() {
        // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
        // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
        //   16      16      16       16      16      16      16      4        4      16
        //   + 21000
        //   + 0
        //   ---------------------------
        //   = 21136
        let rlp_encoded: u256 = 0xc981f781808184000012;

        let input = rlp_encoded.to_be_bytes();
        let to: EthAddress = 'vitalik.eth'.try_into().unwrap();

        let access_list = [
            AccessListItem { ethereum_address: evm_address(), storage_keys: [1, 2, 3, 4, 5].span() }
        ].span();

        let tx: Transaction = Transaction::Eip2930(
            TxEip2930 {
                to: to.into(),
                nonce: 0,
                gas_price: 50,
                gas_limit: 433926,
                value: 1,
                input,
                chain_id: 0x1,
                access_list
            }
        );

        let expected_cost: u64 = 21136 + ACCESS_LIST_ADDRESS + 5 * ACCESS_LIST_STORAGE_KEY;
        let out_cost: u64 = calculate_intrinsic_gas_cost(@tx);

        assert_eq!(out_cost, expected_cost, "wrong cost");
    }


    #[test]
    fn test_calculate_intrinsic_gas_cost_without_destination() {
        // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
        // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
        //   16      16      16       16      16      16      16      4        4      16
        //   + 21000
        //   + (32000 + 2)
        //   ---------------------------
        //   = 53138
        let rlp_encoded: u256 = 0xc981f781808184000012;

        let input = rlp_encoded.to_be_bytes();

        let tx: Transaction = Transaction::Legacy(
            TxLegacy {
                to: Option::None.into(),
                nonce: 0,
                gas_price: 50,
                gas_limit: 433926,
                value: 1,
                input,
                chain_id: Option::Some(0x1)
            }
        );

        let expected_cost: u64 = 53138;
        let out_cost: u64 = calculate_intrinsic_gas_cost(@tx);

        assert_eq!(out_cost, expected_cost, "wrong cost");
    }

    #[test]
    fn test_calculate_memory_allocation_cost() {
        let size_in_bytes: usize = 10018613;
        let expected_cost: u64 = 192385220;
        let out_cost: u64 = calculate_memory_gas_cost(size_in_bytes);
        assert_eq!(out_cost, expected_cost, "wrong cost");
    }
}
