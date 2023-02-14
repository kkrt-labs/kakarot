// SPDX-License-Identifier: MIT

%lang starknet

from kakarot.constants import Constants
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.cairo_keccak.keccak import keccak, finalize_keccak, keccak_bigend
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from utils.rlp import RLP
from utils.utils import Helpers

// @title EthTransaction utils
// @notice This file contains utils for decoding eth transactions
// @custom:namespace EthTransaction
namespace EthTransaction {
    func decode_legacy_tx{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(tx_data_len: felt, tx_data: felt*) -> (
        gas_limit: felt,
        destination: felt,
        amount: felt,
        payload_len: felt,
        payload: felt*,
        tx_hash: Uint256,
        v: felt,
        r: Uint256,
        s: Uint256,
    ) {
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
        alloc_locals;

        let (local items: RLP.Item*) = alloc();
        RLP.decode(tx_data_len, tx_data, items);
        // the tx is a list of fields, hence first level RLP decoding
        // is a single item, which is indeed the sought list
        assert [items].is_list = TRUE;
        let (local sub_items: RLP.Item*) = alloc();
        RLP.decode([items].data_len, [items].data, sub_items);

        // Verify signature
        // The signature is at the end of the rlp encoded list and takes
        // 5 bytes for v = 1 byte for len (=4) + 4 bytes for {0,1} + CHAIN_ID * 2 + 35
        // 33 bytes for r = 1 byte for len (=32) + 32 bytes for r word
        // 33 bytes for s = 1 byte for len (=32) + 32 bytes for s word
        // This signature_len depends on CHAIN_ID, which is currently 0x 4b 4b 52 54
        local signature_len = 1 + 4 + 1 + 32 + 1 + 32;
        local signature_start_index = 6;

        // 1. extract v, r, s
        let (v) = Helpers.bytes_to_felt(
            sub_items[signature_start_index].data_len, sub_items[signature_start_index].data, 0
        );
        let v = (v - 2 * Constants.CHAIN_ID - 35);
        let r = Helpers.bytes32_to_uint256(sub_items[signature_start_index + 1].data);
        let s = Helpers.bytes32_to_uint256(sub_items[signature_start_index + 2].data);

        // 2. Encode signed tx data
        // Copy encoded data from input
        let (local signed_data: felt*) = alloc();
        memcpy(signed_data, [items].data, [items].data_len - signature_len);
        // Append CHAIN_ID, 0, 0
        assert [signed_data + [items].data_len - signature_len] = 0x84;  // 4 bytes
        assert [signed_data + [items].data_len - signature_len + 1] = 0x4b;  // K
        assert [signed_data + [items].data_len - signature_len + 2] = 0x4b;  // K
        assert [signed_data + [items].data_len - signature_len + 3] = 0x52;  // R
        assert [signed_data + [items].data_len - signature_len + 4] = 0x54;  // T
        assert [signed_data + [items].data_len - signature_len + 5] = 0x80;  // 0
        assert [signed_data + [items].data_len - signature_len + 6] = 0x80;  // 0
        let (rlp_data: felt*) = alloc();
        let (rlp_data_len) = RLP.encode_list(
            data_len=[items].data_len - signature_len + 7, data=signed_data, rlp=rlp_data
        );
        let (local words: felt*) = alloc();
        let (keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        with keccak_ptr {
            // From keccak/keccak_bigend doc:
            // > To use this function, split the input into words of 64 bits (little endian).
            // > Same as keccak, but outputs the hash in big endian representation.
            // > Note that the input is still treated as little endian.
            Helpers.bytes_to_bytes8_little_endian(
                bytes_len=rlp_data_len,
                bytes=rlp_data,
                index=0,
                size=rlp_data_len,
                bytes8=0,
                bytes8_shift=0,
                dest=words,
                dest_index=0,
            );
            let (tx_hash) = keccak_bigend(inputs=words, n_bytes=rlp_data_len);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        let gas_limit_idx = 2;
        let (gas_limit) = Helpers.bytes_to_felt(
            sub_items[gas_limit_idx].data_len, sub_items[gas_limit_idx].data, 0
        );
        let (destination) = Helpers.bytes_to_felt(
            sub_items[gas_limit_idx + 1].data_len, sub_items[gas_limit_idx + 1].data, 0
        );
        let (amount) = Helpers.bytes_to_felt(
            sub_items[gas_limit_idx + 2].data_len, sub_items[gas_limit_idx + 2].data, 0
        );
        let payload_len = sub_items[gas_limit_idx + 3].data_len;
        let payload: felt* = sub_items[gas_limit_idx + 3].data;
        return (gas_limit, destination, amount, payload_len, payload, tx_hash, v, r, s);
    }

    func decode_tx{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(tx_data_len: felt, tx_data: felt*) -> (
        gas_limit: felt,
        destination: felt,
        amount: felt,
        payload_len: felt,
        payload: felt*,
        tx_hash: Uint256,
        v: felt,
        r: Uint256,
        s: Uint256,
    ) {
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1559.md#specification
        alloc_locals;
        tempvar tx_type = [tx_data];

        let (local items: RLP.Item*) = alloc();
        RLP.decode(tx_data_len - 1, tx_data + 1, items);
        // the tx is a list of fields, hence first level RLP decoding
        // is a single item, which is indeed the sought list
        assert [items].is_list = TRUE;
        let (local sub_items: RLP.Item*) = alloc();
        RLP.decode([items].data_len, [items].data, sub_items);

        // Verify signature
        // The signature is at the end of the rlp encoded list and takes
        // 1 byte for v
        // 33 bytes for r = 1 byte for len (=32) + 32 bytes for r word
        // 33 bytes for s = 1 byte for len (=32) + 32 bytes for s word
        local signature_len = 1 + 1 + 32 + 1 + 32;
        local signature_start_index = tx_type + 7;
        local chain_id_idx = 0;
        // 1. extract v, r, s
        let (chain_id) = Helpers.bytes_to_felt(
            sub_items[chain_id_idx].data_len, sub_items[chain_id_idx].data, 0
        );
        assert chain_id = Constants.CHAIN_ID;
        let (v) = Helpers.bytes_to_felt(
            sub_items[signature_start_index].data_len, sub_items[signature_start_index].data, 0
        );
        let r = Helpers.bytes32_to_uint256(sub_items[signature_start_index + 1].data);
        let s = Helpers.bytes32_to_uint256(sub_items[signature_start_index + 2].data);

        let (local signed_data: felt*) = alloc();
        assert [signed_data] = tx_type;
        let (rlp_len) = RLP.encode_list(
            [items].data_len - signature_len, [items].data, signed_data + 1
        );

        let (local words: felt*) = alloc();
        let (keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        with keccak_ptr {
            // From keccak/keccak_bigend doc:
            // > To use this function, split the input into words of 64 bits (little endian).
            // > Same as keccak, but outputs the hash in big endian representation.
            // > Note that the input is still treated as little endian.
            Helpers.bytes_to_bytes8_little_endian(
                bytes_len=rlp_len + 1,
                bytes=signed_data,
                index=0,
                size=rlp_len + 1,
                bytes8=0,
                bytes8_shift=0,
                dest=words,
                dest_index=0,
            );
            let (tx_hash) = keccak_bigend(inputs=words, n_bytes=rlp_len + 1);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        let gas_limit_idx = tx_type + 2;
        let (gas_limit) = Helpers.bytes_to_felt(
            sub_items[gas_limit_idx].data_len, sub_items[gas_limit_idx].data, 0
        );
        let (destination) = Helpers.bytes_to_felt(
            sub_items[gas_limit_idx + 1].data_len, sub_items[gas_limit_idx + 1].data, 0
        );
        let (amount) = Helpers.bytes_to_felt(
            sub_items[gas_limit_idx + 2].data_len, sub_items[gas_limit_idx + 2].data, 0
        );
        let payload_len = sub_items[gas_limit_idx + 3].data_len;
        let payload: felt* = sub_items[gas_limit_idx + 3].data;
        return (gas_limit, destination, amount, payload_len, payload, tx_hash, v, r, s);
    }

    func is_legacy_tx{range_check_ptr}(tx_data: felt*) -> felt {
        tempvar type = [tx_data];
        // See https://eips.ethereum.org/EIPS/eip-2718#transactiontype-only-goes-up-to-0x7f
        return is_le(0xc0, type);
    }

    func decode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(tx_data_len: felt, tx_data: felt*) -> (
        gas_limit: felt,
        destination: felt,
        amount: felt,
        payload_len: felt,
        payload: felt*,
        tx_hash: Uint256,
        v: felt,
        r: Uint256,
        s: Uint256,
    ) {
        let _is_legacy = is_legacy_tx(tx_data);
        if (_is_legacy == FALSE) {
            return decode_tx(tx_data_len, tx_data);
        } else {
            return decode_legacy_tx(tx_data_len, tx_data);
        }
    }

    func validate{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(address: felt, tx_data_len: felt, tx_data: felt*) {
        alloc_locals;
        let (gas_limit, destination, amount, payload_len, payload, tx_hash, v, r, s) = decode(
            tx_data_len, tx_data
        );
        if (destination == FALSE){
            with_attr error_message("ExternallyOwnedAccount: account creations are not payable") {
                assert amount = 0;
            }
        }
        let (local keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;
        with keccak_ptr {
            verify_eth_signature_uint256(msg_hash=tx_hash, r=r, s=s, v=v, eth_address=address);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);
        return ();
    }
}
