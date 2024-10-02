use core::fmt::{Debug, Formatter, Error, Display};
use utils::traits::bytes::ToBytes;

// STACK

// INSTRUCTIONS
pub const PC_OUT_OF_BOUNDS: felt252 = 'KKT: pc >= bytecode length';

// TYPE CONVERSION
pub const TYPE_CONVERSION_ERROR: felt252 = 'KKT: type conversion error';

// NUMERIC OPERATIONS
pub const BALANCE_OVERFLOW: felt252 = 'KKT: balance overflow';

// JUMP
pub const INVALID_DESTINATION: felt252 = 'KKT: invalid JUMP destination';

// CALL
pub const VALUE_TRANSFER_IN_STATIC_CALL: felt252 = 'KKT: transfer value in static';
pub const ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION: felt252 = 'KKT: active state in end call';
pub const MISSING_PARENT_CONTEXT: felt252 = 'KKT: missing parent context';
pub const CALL_GAS_GT_GAS_LIMIT: felt252 = 'KKT: call gas gt gas limit';

// EVM STATE

// STARKNET_SYSCALLS
pub const READ_SYSCALL_FAILED: felt252 = 'KKT: read syscall failed';
pub const BLOCK_HASH_SYSCALL_FAILED: felt252 = 'KKT: block_hash syscall failed';
pub const WRITE_SYSCALL_FAILED: felt252 = 'KKT: write syscall failed';
pub const CONTRACT_SYSCALL_FAILED: felt252 = 'KKT: contract syscall failed';
pub const EXECUTION_INFO_SYSCALL_FAILED: felt252 = 'KKT: exec info syscall failed';

// CREATE
pub const CONTRACT_ACCOUNT_EXISTS: felt252 = 'KKT: Contract Account exists';
pub const EOA_EXISTS: felt252 = 'KKT: EOA already exists';
pub const ACCOUNT_EXISTS: felt252 = 'KKT: Account already exists';
pub const DEPLOYMENT_FAILED: felt252 = 'KKT: deployment failed';

// TRANSACTION ORIGIN
pub const CALLING_FROM_UNDEPLOYED_ACCOUNT: felt252 = 'EOA: from is undeployed EOA';
pub const CALLING_FROM_CA: felt252 = 'EOA: from is a contract account';

#[derive(Drop, Copy, PartialEq)]
pub enum EVMError {
    StackOverflow,
    StackUnderflow,
    TypeConversionError: felt252,
    NumericOperations: felt252,
    InsufficientBalance,
    ReturnDataOutOfBounds,
    InvalidJump,
    InvalidCode,
    NotImplemented,
    InvalidParameter: felt252,
    InvalidOpcode: u8,
    WriteInStaticContext,
    Collision,
    OutOfGas,
    Assertion,
    DepthLimit,
    MemoryLimitOOG,
    NonceOverflow
}

#[generate_trait]
pub impl EVMErrorImpl of EVMErrorTrait {
    fn to_string(self: EVMError) -> felt252 {
        match self {
            EVMError::StackOverflow => 'stack overflow',
            EVMError::StackUnderflow => 'stack underflow',
            EVMError::TypeConversionError(error_message) => error_message,
            EVMError::NumericOperations(error_message) => error_message,
            EVMError::InsufficientBalance => 'insufficient balance',
            EVMError::ReturnDataOutOfBounds => 'return data out of bounds',
            EVMError::InvalidJump => 'invalid jump destination',
            EVMError::InvalidCode => 'invalid code',
            EVMError::NotImplemented => 'not implemented',
            EVMError::InvalidParameter(error_message) => error_message,
            // TODO: refactor with dynamic strings once supported
            EVMError::InvalidOpcode => 'invalid opcode'.into(),
            EVMError::WriteInStaticContext => 'write protection',
            EVMError::Collision => 'create collision'.into(),
            EVMError::OutOfGas => 'out of gas'.into(),
            EVMError::Assertion => 'assertion failed'.into(),
            EVMError::DepthLimit => 'max call depth exceeded'.into(),
            EVMError::MemoryLimitOOG => 'memory limit out of gas'.into(),
            EVMError::NonceOverflow => 'nonce overflow'.into(),
        }
    }

    fn to_bytes(self: EVMError) -> Span<u8> {
        let error_message: felt252 = self.to_string();
        let error_message: u256 = error_message.into();
        error_message.to_be_bytes()
    }
}

pub impl DebugEVMError of Debug<EVMError> {
    fn fmt(self: @EVMError, ref f: Formatter) -> Result<(), Error> {
        let error_message = (*self).to_string();
        Display::fmt(@error_message, ref f)
    }
}

#[inline(always)]
pub fn ensure(cond: bool, err: EVMError) -> Result<(), EVMError> {
    if cond {
        Result::Ok(())
    } else {
        Result::Err(err)
    }
}
