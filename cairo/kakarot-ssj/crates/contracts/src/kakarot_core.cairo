pub mod eth_rpc;
pub mod interface;
mod kakarot;
pub use interface::{
    IKakarotCore, IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait,
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};
pub use kakarot::KakarotCore;
