use core::num::traits::Bounded;
use core::result::ResultTrait;
use core::starknet::syscalls::deploy_syscall;
use core::starknet::{EthAddress, ContractAddress};
use crate::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcher, interface::IExtendedKakarotCoreDispatcherTrait
};
use evm::model::{Address};

use evm::test_utils::{other_starknet_address, sequencer_evm_address, chain_id};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::start_cheat_chain_id_global;
use snforge_std::{
    declare, DeclareResultTrait, start_cheat_caller_address, start_cheat_sequencer_address_global,
    stop_cheat_caller_address, start_cheat_caller_address_global, cheat_caller_address, CheatSpan
};
use utils::constants::BLOCK_GAS_LIMIT;
use utils::eth_transaction::legacy::TxLegacy;


pub mod constants {
    use core::starknet::{EthAddress, contract_address_const, ContractAddress};
    pub fn ZERO() -> ContractAddress {
        contract_address_const::<0>()
    }

    pub fn OWNER() -> ContractAddress {
        contract_address_const::<0xabde1>()
    }

    pub fn OTHER() -> ContractAddress {
        contract_address_const::<0xe1145>()
    }

    pub fn EVM_ADDRESS() -> EthAddress {
        0xc0ffee.try_into().unwrap()
    }

    pub fn ETH_BANK() -> ContractAddress {
        contract_address_const::<0x777>()
    }
}

pub fn deploy_native_token() -> IERC20Dispatcher {
    let name: ByteArray = "STARKNET_ETH";
    let symbol: ByteArray = "ETH";
    let initial_supply = Bounded::<u256>::MAX;

    let mut calldata = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    constants::ETH_BANK().serialize(ref calldata);

    let class = declare("ERC20").unwrap().contract_class().class_hash;
    let maybe_address = deploy_syscall(*class, 0, calldata.span(), false);
    match maybe_address {
        Result::Ok((contract_address, _)) => { IERC20Dispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}

pub fn deploy_kakarot_core(
    native_token: ContractAddress, mut eoas: Span<EthAddress>
) -> IExtendedKakarotCoreDispatcher {
    let account_contract_class_hash = declare("AccountContract")
        .unwrap()
        .contract_class()
        .class_hash;
    let uninitialized_account_class_hash = declare("UninitializedAccount")
        .unwrap()
        .contract_class()
        .class_hash;
    let kakarot_core_class_hash = declare("KakarotCore").unwrap().contract_class().class_hash;
    let mut calldata: Array<felt252> = array![
        other_starknet_address().into(),
        native_token.into(),
        (*account_contract_class_hash).into(),
        (*uninitialized_account_class_hash).into(),
        'coinbase',
        BLOCK_GAS_LIMIT.into(),
    ];

    Serde::serialize(@eoas, ref calldata);

    let maybe_address = deploy_syscall(
        (*kakarot_core_class_hash).into(), 0, calldata.span(), false
    );

    let kakarot_core = match maybe_address {
        Result::Ok((
            contract_address, _
        )) => { IExtendedKakarotCoreDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    };
    cheat_caller_address(
        kakarot_core.contract_address, other_starknet_address(), CheatSpan::TargetCalls(1)
    );
    kakarot_core.set_base_fee(1000);

    kakarot_core
}

pub fn deploy_contract_account(
    kakarot_core: IExtendedKakarotCoreDispatcher, evm_address: EthAddress, bytecode: Span<u8>
) -> Address {
    let eoa = deploy_eoa(kakarot_core, evm_address);
    let starknet_address = eoa.contract_address;
    start_cheat_caller_address(starknet_address, kakarot_core.contract_address);
    IAccountDispatcher { contract_address: starknet_address }.set_nonce(1);
    IAccountDispatcher { contract_address: starknet_address }.write_bytecode(bytecode);
    stop_cheat_caller_address(starknet_address);
    Address { evm: evm_address, starknet: starknet_address }
}

pub fn deploy_eoa(
    kakarot_core: IExtendedKakarotCoreDispatcher, evm_address: EthAddress
) -> IAccountDispatcher {
    let starknet_address = kakarot_core.deploy_externally_owned_account(evm_address);
    IAccountDispatcher { contract_address: starknet_address }
}

pub fn call_transaction(
    chain_id: u64, destination: Option<EthAddress>, input: Span<u8>
) -> TxLegacy {
    TxLegacy {
        chain_id: Option::Some(chain_id),
        nonce: 0,
        gas_price: 0,
        gas_limit: 500000000,
        to: destination.into(),
        value: 0,
        input
    }
}

pub fn fund_account_with_native_token(
    contract_address: ContractAddress, native_token: IERC20Dispatcher, amount: u256,
) {
    start_cheat_caller_address(native_token.contract_address, constants::ETH_BANK());
    native_token.transfer(contract_address, amount);
    stop_cheat_caller_address(native_token.contract_address);
}

pub fn setup_contracts_for_testing() -> (IERC20Dispatcher, IExtendedKakarotCoreDispatcher) {
    let sequencer: EthAddress = sequencer_evm_address();
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address, [sequencer].span());

    let sequencer_sn_address = kakarot_core.address_registry(sequencer);
    start_cheat_sequencer_address_global(sequencer_sn_address);
    start_cheat_chain_id_global(chain_id().into());
    return (native_token, kakarot_core);
}
