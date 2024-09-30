use contracts::account_contract::{
    AccountContract, IAccountDispatcher, IAccountDispatcherTrait, OutsideExecution
};
use contracts::kakarot_core::interface::{
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};
use contracts::test_data::{counter_evm_bytecode, eip_2930_rlp_encoded_counter_inc_tx,};
use contracts::test_utils::{
    setup_contracts_for_testing, deploy_contract_account, fund_account_with_native_token,
    call_transaction
};
use core::num::traits::Bounded;
use core::starknet::account::Call;
use core::starknet::secp256_trait::Signature;
use core::starknet::{ContractAddress, contract_address_const, EthAddress, Event};
use evm::test_utils::chain_id;
use evm::test_utils::other_evm_address;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcher;
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, start_cheat_transaction_hash, spy_events,
    EventSpyTrait, CheatSpan, cheat_caller_address, stop_cheat_block_timestamp,
    start_cheat_block_timestamp, start_cheat_chain_id_global, stop_cheat_chain_id_global,
    start_cheat_caller_address_global, stop_cheat_caller_address_global
};

use snforge_utils::snforge_utils::EventsFilterBuilderTrait;
use utils::eth_transaction::transaction::Transaction;
use utils::eth_transaction::tx_type::TxType;
use utils::helpers::u256_to_bytes_array;
use utils::serialization::{serialize_bytes, serialize_transaction_signature};
use utils::test_data::{legacy_rlp_encoded_tx, eip_2930_encoded_tx, eip_1559_encoded_tx};

fn transaction_signer() -> EthAddress {
    0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466.try_into().unwrap()
}

const PLACEHOLDER_SIGNATURE: [felt252; 5] = [1, 2, 3, 4, 0];

const SNIP9_CALLER: felt252 = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf;

#[derive(Drop)]
struct CallBuilder {
    call: Call
}

#[generate_trait]
impl CallBuilderImpl of CallBuilderTrait {
    fn new(kakarot_core: ContractAddress) -> CallBuilder {
        CallBuilder {
            call: Call {
                to: kakarot_core,
                selector: selector!("eth_send_transaction"),
                calldata: serialize_bytes(eip_2930_encoded_tx()).span()
            }
        }
    }

    fn with_to(mut self: CallBuilder, to: ContractAddress) -> CallBuilder {
        self.call.to = to;
        self
    }

    fn with_selector(mut self: CallBuilder, selector: felt252) -> CallBuilder {
        self.call.selector = selector;
        self
    }

    fn with_calldata(mut self: CallBuilder, calldata: Span<u8>) -> CallBuilder {
        self.call.calldata = serialize_bytes(calldata).span();
        self
    }

    fn build(mut self: CallBuilder) -> Call {
        return self.call;
    }
}

#[derive(Drop)]
struct OutsideExecutionBuilder {
    outside_execution: OutsideExecution
}

#[generate_trait]
impl OutsideExecutionBuilderImpl of OutsideExecutionBuilderTrait {
    fn new(kakarot_core: ContractAddress) -> OutsideExecutionBuilder {
        OutsideExecutionBuilder {
            outside_execution: OutsideExecution {
                caller: 'ANY_CALLER'.try_into().unwrap(),
                nonce: 0,
                execute_after: 998,
                execute_before: 1000,
                calls: [
                    CallBuilderTrait::new(kakarot_core).build(),
                ].span()
            }
        }
    }

    fn with_caller(
        mut self: OutsideExecutionBuilder, caller: ContractAddress
    ) -> OutsideExecutionBuilder {
        self.outside_execution.caller = caller;
        self
    }

    fn with_nonce(mut self: OutsideExecutionBuilder, nonce: u64) -> OutsideExecutionBuilder {
        self.outside_execution.nonce = nonce;
        self
    }

    fn with_execute_after(
        mut self: OutsideExecutionBuilder, execute_after: u64
    ) -> OutsideExecutionBuilder {
        self.outside_execution.execute_after = execute_after;
        self
    }

    fn with_execute_before(
        mut self: OutsideExecutionBuilder, execute_before: u64
    ) -> OutsideExecutionBuilder {
        self.outside_execution.execute_before = execute_before;
        self
    }

    fn with_calls(mut self: OutsideExecutionBuilder, calls: Span<Call>) -> OutsideExecutionBuilder {
        self.outside_execution.calls = calls;
        self
    }

    fn build(mut self: OutsideExecutionBuilder) -> OutsideExecution {
        return self.outside_execution;
    }
}

fn set_up() -> (IExtendedKakarotCoreDispatcher, IAccountDispatcher, IERC20CamelDispatcher) {
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    // When we deploy the EOA, we use get_caller_address to get the address of the KakarotCore
    // contract and set the caller address to that.
    // Therefore, we need to stop the global caller address cheat so that the EOA is deployed
    // by the real KakarotCore contract and not the one impersonated by the cheat
    stop_cheat_caller_address_global();
    let eoa = IAccountDispatcher {
        contract_address: kakarot_core.deploy_externally_owned_account(transaction_signer())
    };
    start_cheat_caller_address_global(kakarot_core.contract_address);

    start_cheat_block_timestamp(eoa.contract_address, 999);
    start_cheat_chain_id_global(chain_id().into());

    (kakarot_core, eoa, native_token)
}

fn tear_down(contract_account: IAccountDispatcher) {
    stop_cheat_chain_id_global();
    stop_cheat_block_timestamp(contract_account.contract_address);
}

#[test]
#[should_panic(expected: 'SNIP9: Invalid caller')]
fn test_execute_from_outside_invalid_caller() {
    let (kakarot_core, contract_account, _) = set_up();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_caller(contract_address_const::<0xb0b>())
        .build();
    let signature = PLACEHOLDER_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'SNIP9: Too early call')]
fn test_execute_from_outside_too_early_call() {
    let (kakarot_core, contract_account, _) = set_up();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_execute_after(999)
        .build();
    let signature = PLACEHOLDER_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'SNIP9: Too late call')]
fn test_execute_from_outside_too_late_call() {
    let (kakarot_core, contract_account, _) = set_up();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_execute_before(999)
        .build();
    let signature = PLACEHOLDER_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'EOA: Invalid signature length')]
fn test_execute_from_outside_inPLACEHOLDER_SIGNATURE_length() {
    let (kakarot_core, contract_account, _) = set_up();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .build();

    let _ = contract_account.execute_from_outside(outside_execution, [].span());

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'KKRT: Multicall not supported')]
fn test_execute_from_outside_multicall_not_supported() {
    let (kakarot_core, contract_account, _) = set_up();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address).build(),
                CallBuilderTrait::new(kakarot_core.contract_address).build(),
            ].span()
        )
        .build();
    let signature = PLACEHOLDER_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'EOA: invalid signature')]
fn test_execute_from_outside_invalid_signature() {
    let (kakarot_core, contract_account, _) = set_up();

    let caller = contract_address_const::<SNIP9_CALLER>();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_caller(caller)
        .build();
    let signature: Span<felt252> = [1, 2, 3, 4, (chain_id() * 2 + 40).into()].span();

    start_cheat_caller_address(contract_account.contract_address, caller);
    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'EOA: could not decode tx')]
fn test_execute_from_outside_invalid_tx() {
    let (kakarot_core, contract_account, _) = set_up();

    let mut faulty_eip_2930_tx = eip_2930_encoded_tx();
    let signature = Signature {
        r: 0x5c4ae1ed01c8df4277f02aa3443f8183ed44627217fd7f27badaed8795906e78,
        s: 0x4d2af576441428d47c174ffddc6e70b980527a57795b3c87a71878f97ecef274,
        y_parity: true
    };
    let _ = faulty_eip_2930_tx.pop_front();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address)
                    .with_calldata(faulty_eip_2930_tx)
                    .build()
            ].span()
        )
        .build();

    let signature = serialize_transaction_signature(signature, TxType::Eip2930, chain_id()).span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'KKRT: Multicall not supported')]
fn test_execute_from_outside_should_fail_with_zero_calls() {
    let (kakarot_core, contract_account, _) = set_up();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls([].span())
        .build();
    let signature = PLACEHOLDER_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}

#[test]
#[should_panic(expected: 'EOA: cannot have code')]
fn test_execute_from_outside_should_fail_account_with_code() {
    let (kakarot_core, _, _) = set_up();

    let contract_address = deploy_contract_account(
        kakarot_core, other_evm_address(), counter_evm_bytecode()
    )
        .starknet;
    let contract_account = IAccountDispatcher { contract_address };

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .build();
    let signature = PLACEHOLDER_SIGNATURE.span();

    start_cheat_block_timestamp(contract_account.contract_address, 999);
    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tear_down(contract_account);
}


#[test]
#[should_panic(expected: 'KKRT: Multicall not supported')]
fn test_execute_from_outside_should_fail_with_multi_calls() {
    let (kakarot_core, eoa, _) = set_up();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address)
                    .with_calldata(legacy_rlp_encoded_tx())
                    .build()
            ; 2].span()
        )
        .build();
    let signature = PLACEHOLDER_SIGNATURE.span();

    let _ = eoa.execute_from_outside(outside_execution, signature);

    tear_down(eoa);
}


#[test]
fn test_execute_from_outside_legacy_tx() {
    let (kakarot_core, eoa, native_token) = set_up();
    fund_account_with_native_token(eoa.contract_address, native_token, Bounded::<u128>::MAX.into());

    let caller = contract_address_const::<SNIP9_CALLER>();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_caller(caller)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address)
                    .with_calldata(legacy_rlp_encoded_tx())
                    .build()
            ].span()
        )
        .build();

    // to reproduce locally:
    // run: cp .env.example .env
    // bun install & bun run scripts/compute_rlp_encoding.ts

    let signature = serialize_transaction_signature(
        Signature {
            r: 0xf2805d01dd4fa240c79039c85a77554fc186cc73c2025d7f8c02bc8fe1a982b5,
            s: 0x27ff351275563c1a29ab9eaeec4a3b63fbc4035d6da6b8b6af52c7993b5869ec,
            y_parity: true
        },
        TxType::Legacy,
        chain_id()
    )
        .span();

    cheat_caller_address(eoa.contract_address, caller, CheatSpan::TargetCalls(1));
    stop_cheat_caller_address(kakarot_core.contract_address);
    let data = eoa.execute_from_outside(outside_execution, signature);

    assert_eq!(data.len(), 1);
    assert_eq!(*data[0], [].span());

    stop_cheat_caller_address(eoa.contract_address);
    tear_down(eoa);
}

#[test]
fn test_execute_from_outside_eip2930_tx() {
    let (kakarot_core, eoa, native_token) = set_up();
    fund_account_with_native_token(eoa.contract_address, native_token, Bounded::<u128>::MAX.into());
    let caller = contract_address_const::<SNIP9_CALLER>();

    // Signature for the default eip2930 tx
    let signature = Signature {
        r: 0x5c4ae1ed01c8df4277f02aa3443f8183ed44627217fd7f27badaed8795906e78,
        s: 0x4d2af576441428d47c174ffddc6e70b980527a57795b3c87a71878f97ecef274,
        y_parity: true
    };

    // Defaults with an eip2930 tx
    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_caller(caller)
        .build();
    let signature = serialize_transaction_signature(signature, TxType::Eip2930, chain_id()).span();

    cheat_caller_address(eoa.contract_address, caller, CheatSpan::TargetCalls(1));
    stop_cheat_caller_address(kakarot_core.contract_address);
    let data = eoa.execute_from_outside(outside_execution, signature);

    assert_eq!(data.len(), 1);
    assert_eq!(*data[0], [].span());

    stop_cheat_caller_address(eoa.contract_address);
    tear_down(eoa);
}


#[test]
fn test_execute_from_outside_eip1559_tx() {
    let (kakarot_core, eoa, native_token) = set_up();
    fund_account_with_native_token(eoa.contract_address, native_token, Bounded::<u128>::MAX.into());

    let caller = contract_address_const::<SNIP9_CALLER>();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_caller(caller)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address)
                    .with_calldata(eip_1559_encoded_tx())
                    .build()
            ].span()
        )
        .build();

    // to reproduce locally:
    // run: cp .env.example .env
    // bun install & bun run scripts/compute_rlp_encoding.ts
    let signature = Signature {
        r: 0xb2563dbafa29dd6f126f0e6581b772d3f07063e2f07fb7bdf73aad34a04c4283,
        s: 0x73df539e40359b81b8f260ed04431de098fc149bc5e27120e6711acabaecd067,
        y_parity: true
    };
    let signature = serialize_transaction_signature(signature, TxType::Eip1559, chain_id()).span();

    // Stop all cheats and only mock the EFO caller.
    stop_cheat_caller_address_global();
    cheat_caller_address(eoa.contract_address, caller, CheatSpan::TargetCalls(1));
    let data = eoa.execute_from_outside(outside_execution, signature);

    assert_eq!(data.len(), 1);
    assert_eq!(*data[0], [].span());

    tear_down(eoa);
}

#[test]
fn test_execute_from_outside_eip_2930_counter_inc_tx() {
    let (kakarot_core, eoa, native_token) = set_up();
    fund_account_with_native_token(eoa.contract_address, native_token, Bounded::<u128>::MAX.into());

    let kakarot_address = kakarot_core.contract_address;

    deploy_contract_account(kakarot_core, other_evm_address(), counter_evm_bytecode());

    start_cheat_caller_address(kakarot_address, eoa.contract_address);

    // Then
    // selector: function get()
    let data_get_tx = [0x6d, 0x4c, 0xe6, 0x3c].span();

    // check counter value is 0 before doing inc
    let tx = call_transaction(chain_id(), Option::Some(other_evm_address()), data_get_tx);

    let (_, return_data, _) = kakarot_core
        .eth_call(origin: transaction_signer(), tx: Transaction::Legacy(tx),);

    assert_eq!(return_data, u256_to_bytes_array(0).span());

    // perform inc on the counter
    let call = Call {
        to: kakarot_address,
        selector: selector!("eth_send_transaction"),
        calldata: serialize_bytes(eip_2930_rlp_encoded_counter_inc_tx()).span()
    };

    start_cheat_transaction_hash(eoa.contract_address, selector!("transaction_hash"));
    start_cheat_block_timestamp(eoa.contract_address, 100);
    cheat_caller_address(
        eoa.contract_address, contract_address_const::<0>(), CheatSpan::TargetCalls(1)
    );
    let mut spy = spy_events();
    let outside_execution = OutsideExecution {
        caller: contract_address_const::<'ANY_CALLER'>(),
        nonce: 0,
        execute_after: 0,
        execute_before: 10000000,
        calls: array![call].span()
    };
    let signature = Signature {
        r: 0x8cd55583b5da62b3fd23586bf4f1ffd496046b9d248a7983ec41bd6fb673f379,
        s: 0x09432a74ec3720a226ac040ce828f92e22350c4d8f7b188693cad035e99372ed,
        y_parity: true
    };
    let signature = serialize_transaction_signature(signature, TxType::Eip2930, chain_id()).span();
    stop_cheat_caller_address(kakarot_core.contract_address);
    let result = eoa.execute_from_outside(outside_execution, signature);
    assert_eq!(result.len(), 1);

    let expected_event = AccountContract::Event::transaction_executed(
        AccountContract::TransactionExecuted {
            response: *result.span()[0], success: true, gas_used: 0
        }
    );
    let mut keys = array![];
    let mut data = array![];
    expected_event.append_keys_and_data(ref keys, ref data);
    let mut contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(eoa.contract_address)
        .with_keys(keys.span())
        .build();

    let mut received_keys = contract_events.events[0].keys.span();
    let mut received_data = contract_events.events[0].data.span();
    let deserialized_received: AccountContract::Event = Event::deserialize(
        ref received_keys, ref received_data
    )
        .unwrap();
    if let AccountContract::Event::transaction_executed(transaction_executed) =
        deserialized_received {
        let expected_response = *result.span()[0];
        let expected_success = true;
        let not_expected_gas_used = 0;
        assert_eq!(transaction_executed.response, expected_response);
        assert_eq!(transaction_executed.success, expected_success);
        assert_ne!(transaction_executed.gas_used, not_expected_gas_used);
    } else {
        panic!("Expected transaction_executed event");
    }
    // check counter value has increased
    let tx = call_transaction(chain_id(), Option::Some(other_evm_address()), data_get_tx);
    let (_, return_data, _) = kakarot_core
        .eth_call(origin: transaction_signer(), tx: Transaction::Legacy(tx),);
    assert_eq!(return_data, u256_to_bytes_array(1).span());
}
