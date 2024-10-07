pub mod backend;
// Call opcodes helpers
mod call_helpers;

// Create opcodes helpers
mod create_helpers;

// Errors module
pub mod errors;

// Gas module
pub mod gas;

// instructions module
pub mod instructions;

// interpreter module
mod interpreter;

// Memory module
mod memory;

// Data Models module
pub mod model;

// instructions module
pub mod precompiles;

// Stack module
mod stack;

// Local state
pub mod state;

#[cfg(target: 'test')]
pub mod test_data;

#[cfg(target: 'test')]
pub mod test_utils;
pub use interpreter::EVMTrait;
