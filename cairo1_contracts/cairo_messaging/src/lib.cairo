//! A simple contract that sends and receives messages from/to
//! the L1 (Ethereum).
//!
//! The reception of the messages is done using the `l1_handler` functions.
//! The messages are sent by using the `send_message_to_l1_syscall` syscall.
//! Author: Glihm https://github.com/glihm/starknet-messaging-dev

/// A custom struct, which is already
/// serializable as `felt252` is serializable.
#[derive(Drop, Serde)]
struct MyData {
    a: felt252,
    b: felt252,
}

#[starknet::interface]
trait IContractL1<T> {
    /// Sends a message to L1 contract with a single felt252 value.
    ///
    /// # Arguments
    ///
    /// * `to_address` - Contract address on L1.
    /// * `value` - Value to be sent in the payload.
    fn send_message_value(ref self: T, to_address: starknet::EthAddress, value: felt252);

    /// Sends a message to L1 contract with a serialized struct.
    /// To send a struct in a payload of a message, you only have to ensure that
    /// your structure is serializable implementing the `Serde` traits. Which
    /// is automatically done if your structure only contains already serializable members.
    ///
    /// # Arguments
    ///
    /// * `to_address` - Contract address on L1.
    /// * `data` - Data to be sent in the payload.
    fn send_message_struct(ref self: T, to_address: starknet::EthAddress, data: MyData);
}

#[starknet::contract]
mod CairoMessaging {
    use super::{IContractL1, MyData};
    use starknet::{EthAddress, SyscallResultTrait};
    use core::num::traits::Zero;
    use starknet::syscalls::send_message_to_l1_syscall;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ValueReceivedFromL1: ValueReceived,
        StructReceivedFromL1: StructReceived,
    }

    #[derive(Drop, starknet::Event)]
    struct ValueReceived {
        #[key]
        l1_address: felt252,
        value: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct StructReceived {
        #[key]
        l1_address: felt252,
        data_a: felt252,
        data_b: felt252,
    }

    /// Handles a message received from L1.
    ///
    /// Only functions that are annotated with `#[l1_handler]` can
    /// receive message from L1, as the sequencer will execute
    /// the contract code using a specific transaction type (`L1HandlerTransaction`)
    /// that can only see endpoints annotated as such.
    ///
    /// # Arguments
    ///
    /// * `from_address` - The L1 contract sending the message.
    /// * `value` - Expected value in the payload.
    ///
    /// In production, you must always check if the `from_address` is
    /// a contract you allowed to send messages, as any contract from L1
    /// can send message to any contract on L2 and vice-versa.
    ///
    /// In this example, the payload is expected to be a single felt value. But it can be any
    /// deserializable struct written in cairo.
    #[l1_handler]
    fn msg_handler_value(ref self: ContractState, from_address: felt252, value: felt252) {
        // assert(from_address == ...);

        assert(value == 123, 'Invalid value');

        self.emit(ValueReceived { l1_address: from_address, value, });
    }

    /// Handles a message received from L1.
    /// In this example, the handler is expecting the data members to both be greater than 0.
    ///
    /// # Arguments
    ///
    /// * `from_address` - The L1 contract sending the message.
    /// * `data` - Expected data in the payload (automatically deserialized by cairo).
    #[l1_handler]
    fn msg_handler_struct(ref self: ContractState, from_address: felt252, data: MyData) {
        // assert(from_address == ...);

        assert(!data.a.is_zero(), 'data.a is invalid');
        assert(!data.b.is_zero(), 'data.b is invalid');

        self.emit(StructReceived { l1_address: from_address, data_a: data.a, data_b: data.b, });
    }

    #[abi(embed_v0)]
    impl ContractL1Impl of IContractL1<ContractState> {
        fn send_message_value(ref self: ContractState, to_address: EthAddress, value: felt252) {
            // Note here, we "serialize" the felt252 value, as the payload must be
            // a `Span<felt252>`.
            send_message_to_l1_syscall(to_address.into(), array![value].span()).unwrap_syscall();
        }

        fn send_message_struct(ref self: ContractState, to_address: EthAddress, data: MyData) {
            // Explicit serialization of our structure `MyData`.
            let mut buf: Array<felt252> = array![];
            data.serialize(ref buf);
            send_message_to_l1_syscall(to_address.into(), buf.span()).unwrap_syscall();
        }
    }
}
