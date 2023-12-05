// SPDX-License-Identifier: MIT

%lang starknet

from kakarot.constants import Constants
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak, cairo_keccak_bigend
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from utils.rlp import RLP
from utils.utils import Helpers
from utils.bytes import bytes_to_bytes8_little_endian

// @title EthTransaction utils
// @notice This file contains utils for decoding eth transactions
// @custom:namespace EthTransaction
namespace EthTransaction {
    // @notice Decode a legacy Ethereum transaction
    // @dev This function decodes a legacy Ethereum transaction in accordance with EIP-155.
    // It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    // transaction hash, and signature (v, r, s). The transaction hash is computed by keccak hashing the signed
    // transaction data, which includes the chain ID in accordance with EIP-155.
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func decode_legacy_tx{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(tx_data_len: felt, tx_data: felt*) -> (
        nonce: felt,
        gas_price: felt,
        gas_limit: felt,
        destination: felt,
        amount: felt,
        payload_len: felt,
        payload: felt*,
        msg_hash: Uint256,
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
        // 1 + r_len bytes for r = 1 byte for len (<= 32) + length in bytes for r word
        // 1 + s_len bytes for s = 1 byte for len (<= 32) + length in bytes for s word
        // This signature_len depends on CHAIN_ID, which is currently 0x 4b 4b 52 54
        local signature_start_index = 6;
        let r_len = sub_items[signature_start_index + 1].data_len;
        let s_len = sub_items[signature_start_index + 2].data_len;
        local signature_len = 1 + 4 + 1 + r_len + 1 + s_len;

        // 1. extract v, r, s
        let (v) = Helpers.bytes_to_felt(
            sub_items[signature_start_index].data_len, sub_items[signature_start_index].data, 0
        );
        let v = (v - 2 * Constants.CHAIN_ID - 35);
        let r = Helpers.bytes_i_to_uint256(sub_items[signature_start_index + 1].data, r_len);
        let s = Helpers.bytes_i_to_uint256(sub_items[signature_start_index + 2].data, s_len);

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
            // From keccak/cairo_keccak_bigend doc:
            // > To use this function, split the input into words of 64 bits (little endian).
            // > Same as keccak, but outputs the hash in big endian representation.
            // > Note that the input is still treated as little endian.
            bytes_to_bytes8_little_endian(words, rlp_data_len, rlp_data);
            let (msg_hash) = cairo_keccak_bigend(inputs=words, n_bytes=rlp_data_len);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        let nonce_idx = 0;
        let (nonce) = Helpers.bytes_to_felt(
            sub_items[nonce_idx].data_len, sub_items[nonce_idx].data, 0
        );
        let (gas_price) = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 1].data_len, sub_items[nonce_idx + 1].data, 0
        );
        let (gas_limit) = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 2].data_len, sub_items[nonce_idx + 2].data, 0
        );
        let (destination) = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 3].data_len, sub_items[nonce_idx + 3].data, 0
        );
        let (amount) = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 4].data_len, sub_items[nonce_idx + 4].data, 0
        );
        let payload_len = sub_items[nonce_idx + 5].data_len;
        let payload: felt* = sub_items[nonce_idx + 5].data;
        return (
            nonce,
            gas_price,
            gas_limit,
            destination,
            amount,
            payload_len,
            payload,
            msg_hash,
            v,
            r,
            s,
        );
    }

    // @notice Decode a modern Ethereum transaction
    // @dev This function decodes a modern Ethereum transaction in accordance with EIP-2718.
    // It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    // transaction hash, and signature (v, r, s). The transaction hash is computed by keccak hashing the signed
    // transaction data, which includes the chain ID as part of the transaction data itself.
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func decode_tx{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(tx_data_len: felt, tx_data: felt*) -> (
        nonce: felt,
        gas_price: felt,
        gas_limit: felt,
        destination: felt,
        amount: felt,
        payload_len: felt,
        payload: felt*,
        msg_hash: Uint256,
        v: felt,
        r: Uint256,
        s: Uint256,
    ) {
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2718.md#specification
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
        let r = Helpers.bytes_i_to_uint256(
            sub_items[signature_start_index + 1].data, sub_items[signature_start_index + 1].data_len
        );
        let s = Helpers.bytes_i_to_uint256(
            sub_items[signature_start_index + 2].data, sub_items[signature_start_index + 2].data_len
        );
        local signature_len = 1 + 1 + sub_items[signature_start_index + 1].data_len + 1 + sub_items[
            signature_start_index + 2
        ].data_len;

        let (local signed_data: felt*) = alloc();
        assert [signed_data] = tx_type;
        let (rlp_len) = RLP.encode_list(
            [items].data_len - signature_len, [items].data, signed_data + 1
        );

        let (local words: felt*) = alloc();
        let (keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        with keccak_ptr {
            // From keccak/cairo_keccak_bigend doc:
            // > To use this function, split the input into words of 64 bits (little endian).
            // > Same as keccak, but outputs the hash in big endian representation.
            // > Note that the input is still treated as little endian.
            bytes_to_bytes8_little_endian(words, rlp_len + 1, signed_data);
            let (msg_hash) = cairo_keccak_bigend(inputs=words, n_bytes=rlp_len + 1);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        let nonce_idx = 1;
        let (nonce) = Helpers.bytes_to_felt(
            sub_items[nonce_idx].data_len, sub_items[nonce_idx].data, 0
        );
        let gas_price_idx = tx_type + nonce_idx;
        let (gas_price) = Helpers.bytes_to_felt(
            sub_items[gas_price_idx].data_len, sub_items[gas_price_idx].data, 0
        );
        let (gas_limit) = Helpers.bytes_to_felt(
            sub_items[gas_price_idx + 1].data_len, sub_items[gas_price_idx + 1].data, 0
        );
        let (destination) = Helpers.bytes_to_felt(
            sub_items[gas_price_idx + 2].data_len, sub_items[gas_price_idx + 2].data, 0
        );
        let (amount) = Helpers.bytes_to_felt(
            sub_items[gas_price_idx + 3].data_len, sub_items[gas_price_idx + 3].data, 0
        );
        let payload_len = sub_items[gas_price_idx + 4].data_len;
        let payload: felt* = sub_items[gas_price_idx + 4].data;
        return (
            nonce,
            gas_price,
            gas_limit,
            destination,
            amount,
            payload_len,
            payload,
            msg_hash,
            v,
            r,
            s,
        );
    }

    // @notice Check if a raw transaction is a legacy Ethereum transaction
    // @dev This function checks if a raw transaction is a legacy Ethereum transaction by checking the transaction type
    // according to EIP-2718. If the transaction type is less than or equal to 0xc0, it's a legacy transaction.
    // @param tx_data The raw transaction data
    func is_legacy_tx{range_check_ptr}(tx_data: felt*) -> felt {
        // See https://eips.ethereum.org/EIPS/eip-2718#transactiontype-only-goes-up-to-0x7f
        tempvar type = [tx_data];
        return is_le(0xc0, type);
    }

    // @notice Decode a raw Ethereum transaction
    // @dev This function decodes a raw Ethereum transaction. It checks if the transaction
    // is a legacy transaction or a modern transaction, and calls the appropriate decode function
    // (decode_legacy_tx or decode_tx) based on the result.
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func decode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(tx_data_len: felt, tx_data: felt*) -> (
        nonce: felt,
        gas_price: felt,
        gas_limit: felt,
        destination: felt,
        amount: felt,
        payload_len: felt,
        payload: felt*,
        msg_hash: Uint256,
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

    // @notice Validate an Ethereum transaction
    // @dev This function validates an Ethereum transaction by checking if the transaction
    // is correctly signed by the given address, and if the nonce in the transaction
    // matches the nonce of the account. It decodes the transaction using the decode function,
    // and then verifies the Ethereum signature on the transaction hash.
    // @param address The address that is supposed to have signed the transaction
    // @param account_nonce The nonce of the account
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func validate{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(address: felt, account_nonce: felt, tx_data_len: felt, tx_data: felt*) {
        alloc_locals;
        let (
            nonce,
            gas_price,
            gas_limit,
            destination,
            amount,
            payload_len,
            payload,
            msg_hash,
            v,
            r,
            s,
        ) = decode(tx_data_len, tx_data);
        assert nonce = account_nonce;
        let (local keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;
        with keccak_ptr {
            verify_eth_signature_uint256(msg_hash=msg_hash, r=r, s=s, v=v, eth_address=address);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);
        return ();
    }
}
