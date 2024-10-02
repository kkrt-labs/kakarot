#[starknet::contract]
pub mod Cairo1HelpersFixture {
    use crate::cairo1_helpers::embeddable_impls;

    const VERSION: felt252 = 2;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Precompiles = embeddable_impls::Precompiles<ContractState>;

    #[abi(embed_v0)]
    impl Helpers = embeddable_impls::Helpers<ContractState>;
}
