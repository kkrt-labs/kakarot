pub mod account_contract;
pub mod cairo1_helpers;
pub mod components;

pub mod errors;

// Kakarot smart contract
pub mod kakarot_core;
pub mod storage;

#[cfg(target: 'test')]
pub mod test_data;

#[cfg(target: 'test')]
pub mod test_utils;

// Account transparent proxy
mod uninitialized_account;
pub use account_contract::{AccountContract, IAccount, IAccountDispatcher, IAccountDispatcherTrait};
pub use cairo1_helpers::{
    Cairo1Helpers, IPrecompiles, IHelpers, IPrecompilesDispatcher, IHelpersDispatcher,
    IPrecompilesDispatcherTrait, IHelpersDispatcherTrait
};
pub use kakarot_core::{
    KakarotCore, IKakarotCore, IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait,
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};
pub use uninitialized_account::{UninitializedAccount};

//TODO: hide this behind a feature flag
pub mod test_contracts {
    pub mod test_upgradeable;
}

pub mod mocks {
    pub mod cairo1_helpers_fixture;
}
