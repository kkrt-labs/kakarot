from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak, cairo_keccak_bigend
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256

from kakarot.constants import Constants
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
    func decode_legacy_tx{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        tx_data_len: felt, tx_data: felt*
    ) -> (
        msg_hash: Uint256,
        nonce: felt,
        gas_price: felt,
        gas_limit: felt,
        destination: felt,
        amount: Uint256,
        chain_id: felt,
        payload_len: felt,
        payload: felt*,
    ) {
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
        alloc_locals;

        let (local words: felt*) = alloc();
        let (keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        with keccak_ptr {
            // From keccak/cairo_keccak_bigend doc:
            // > To use this function, split the input into words of 64 bits (little endian).
            // > Same as keccak, but outputs the hash in big endian representation.
            // > Note that the input is still treated as little endian.
            bytes_to_bytes8_little_endian(words, tx_data_len, tx_data);
            let (msg_hash) = cairo_keccak_bigend(inputs=words, n_bytes=tx_data_len);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        let (items: RLP.Item*) = alloc();
        RLP.decode(items, tx_data_len, tx_data);

        // the tx is a list of fields, hence first level RLP decoding
        // is a single item, which is indeed the sought list
        assert [items].is_list = TRUE;
        let sub_items_len = [items].data_len;
        let sub_items = cast([items].data, RLP.Item*);

        let nonce_idx = 0;
        let nonce = Helpers.bytes_to_felt(sub_items[nonce_idx].data_len, sub_items[nonce_idx].data);
        let gas_price = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 1].data_len, sub_items[nonce_idx + 1].data
        );
        let gas_limit = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 2].data_len, sub_items[nonce_idx + 2].data
        );
        let destination = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 3].data_len, sub_items[nonce_idx + 3].data
        );
        let amount = Helpers.bytes_i_to_uint256(
            sub_items[nonce_idx + 4].data, sub_items[nonce_idx + 4].data_len
        );
        let payload_len = sub_items[nonce_idx + 5].data_len;
        let payload: felt* = sub_items[nonce_idx + 5].data;

        let chain_id = Helpers.bytes_to_felt(
            sub_items[nonce_idx + 6].data_len, sub_items[nonce_idx + 6].data
        );

        return (
            msg_hash,
            nonce,
            gas_price,
            gas_limit,
            destination,
            amount,
            chain_id,
            payload_len,
            payload,
        );
    }

    // @notice Decode a modern Ethereum transaction
    // @dev This function decodes a modern Ethereum transaction in accordance with EIP-2718.
    // It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    // transaction hash, and signature (v, r, s). The transaction hash is computed by keccak hashing the signed
    // transaction data, which includes the chain ID as part of the transaction data itself.
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func decode_tx{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        tx_data_len: felt, tx_data: felt*
    ) -> (
        msg_hash: Uint256,
        nonce: felt,
        gas_price: felt,
        gas_limit: felt,
        destination: felt,
        amount: Uint256,
        chain_id: felt,
        payload_len: felt,
        payload: felt*,
    ) {
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2718.md#specification
        alloc_locals;

        let (local words: felt*) = alloc();
        let (keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        with keccak_ptr {
            // From keccak/cairo_keccak_bigend doc:
            // > To use this function, split the input into words of 64 bits (little endian).
            // > Same as keccak, but outputs the hash in big endian representation.
            // > Note that the input is still treated as little endian.
            bytes_to_bytes8_little_endian(words, tx_data_len, tx_data);
            let (msg_hash) = cairo_keccak_bigend(inputs=words, n_bytes=tx_data_len);
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);

        tempvar tx_type = [tx_data];

        let (items: RLP.Item*) = alloc();
        RLP.decode(items, tx_data_len - 1, tx_data + 1);
        // the tx is a list of fields, hence first level RLP decoding
        // is a single item, which is indeed the sought list
        assert [items].is_list = TRUE;
        let sub_items_len = [items].data_len;
        let sub_items = cast([items].data, RLP.Item*);

        let chain_id = Helpers.bytes_to_felt(sub_items[0].data_len, sub_items[0].data);

        let nonce_idx = 1;
        let nonce = Helpers.bytes_to_felt(sub_items[1].data_len, sub_items[1].data);
        let gas_price_idx = tx_type + 1;
        let gas_price = Helpers.bytes_to_felt(
            sub_items[gas_price_idx].data_len, sub_items[gas_price_idx].data
        );
        let gas_limit = Helpers.bytes_to_felt(
            sub_items[gas_price_idx + 1].data_len, sub_items[gas_price_idx + 1].data
        );
        let destination = Helpers.bytes_to_felt(
            sub_items[gas_price_idx + 2].data_len, sub_items[gas_price_idx + 2].data
        );
        let amount = Helpers.bytes_i_to_uint256(
            sub_items[gas_price_idx + 3].data, sub_items[gas_price_idx + 3].data_len
        );
        let payload_len = sub_items[gas_price_idx + 4].data_len;
        let payload: felt* = sub_items[gas_price_idx + 4].data;

        let access_list_len = sub_items[gas_price_idx + 5].data_len;
        let access_list_ptr = sub_items[gas_price_idx + 5].data;
        return (
            msg_hash,
            nonce,
            gas_price,
            gas_limit,
            destination,
            amount,
            chain_id,
            payload_len,
            payload,
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
    func decode{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        tx_data_len: felt, tx_data: felt*
    ) -> (
        msg_hash: Uint256,
        nonce: felt,
        gas_price: felt,
        gas_limit: felt,
        destination: felt,
        amount: Uint256,
        chain_id: felt,
        payload_len: felt,
        payload: felt*,
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
    func validate{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        address: felt,
        account_nonce: felt,
        r: Uint256,
        s: Uint256,
        v: felt,
        tx_data_len: felt,
        tx_data: felt*,
    ) {
        alloc_locals;
        let (msg_hash, nonce, _gas_price, _gas_limit, _, _, chain_id, _, _) = decode(
            tx_data_len, tx_data
        );
        assert nonce = account_nonce;
        assert chain_id = Constants.CHAIN_ID;

        // Note: here, the validate process assumes an ECDSA signature, and r, s, v field
        // Technically, the transaction type can determine the signature scheme.
        let _is_legacy = is_legacy_tx(tx_data);
        if (_is_legacy != FALSE) {
            tempvar y_parity = (v - 2 * Constants.CHAIN_ID - 35);
        } else {
            tempvar y_parity = v;
        }

        let (local words: felt*) = alloc();
        let (keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        with keccak_ptr {
            verify_eth_signature_uint256(
                msg_hash=msg_hash, r=r, s=s, v=y_parity, eth_address=address
            );
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);
        return ();
    }

    struct AccessList {
        address: felt,
        storage_keys_len: felt,
        storage_keys: Uint256*,
    }

    // @notice Parses the RLP-decoded access list and returns an array containing tuples
    // of (address, storage_keys_len, storage_keys) for each entry in the access list.
    // @param list_len The length of the access list. Each entry in the access list
    // takes 3 felts, so a length of 6 means 2 entries.
    // @param access_list The RLP-decoded access list.
    func parse_access_list{range_check_ptr}(list_len: felt, list_items: RLP.Item*) -> (
        felt, AccessList*
    ) {
        alloc_locals;
        if (list_len == 0) {
            return (0, cast(0, AccessList*));
        }

        let (parsed_list: AccessList*) = alloc();

        let parsed_len = _parse_access_list(list_len, list_items, 0, parsed_list);

        return (parsed_len, parsed_list);
    }

    // Each item in the access list is a List of two elements [Address, List<StorageKeys>]
    func _parse_access_list{range_check_ptr}(
        list_len: felt, list_items: RLP.Item*, parsed_list_len: felt, parsed_list: AccessList*
    ) -> felt {
        alloc_locals;
        if (list_len == 0) {
            return parsed_list_len;
        }

        // Each item should be of length 2, as it's a List<address, List<storage_keys>>
        let address_item = [list_items];
        let address_ptr = list_items.data;
        let address_len = list_items.data_len;
        let address = Helpers.bytes_to_felt(address_len, address_ptr);

        let keys_item = [list_items + RLP.Item.SIZE];
        let keys_list_len = keys_item.data_len;
        let keys_list = cast(keys_item.data, RLP.Item*);

        let (parsed_keys_len, parsed_keys) = parse_storage_keys(keys_list_len, keys_list);
        assert [parsed_list] = AccessList(
            address=address, storage_keys_len=parsed_keys_len, storage_keys=parsed_keys
        );

        return _parse_access_list(
            list_len - 2 * RLP.Item.SIZE,
            list_items + 2 * RLP.Item.SIZE,
            parsed_list_len + 1,
            parsed_list + AccessList.SIZE,
        );
    }

    // Parses the List of storage keys associated to an address
    func parse_storage_keys{range_check_ptr}(keys_list_len: felt, keys_list: RLP.Item*) -> (
        felt, Uint256*
    ) {
        alloc_locals;
        if (keys_list_len == 0) {
            return (0, cast(0, Uint256*));
        }

        let (parsed_keys: Uint256*) = alloc();
        let parsed_keys_len = _parse_storage_keys(keys_list_len, keys_list, 0, parsed_keys);

        return (parsed_keys_len, parsed_keys);
    }

    // Recursively parses storage keys associated to an address
    func _parse_storage_keys{range_check_ptr}(
        keys_list_len: felt, keys_list: RLP.Item*, parsed_keys_len: felt, parsed_keys: Uint256*
    ) -> felt {
        alloc_locals;
        if (keys_list_len == 0) {
            return parsed_keys_len;
        }

        let key_len = keys_list.data_len;
        let key_bytes = keys_list.data;
        let key = Helpers.bytes_i_to_uint256(key_bytes, key_len);
        assert [parsed_keys] = key;

        return _parse_storage_keys(
            keys_list_len - RLP.Item.SIZE,
            keys_list + RLP.Item.SIZE,
            parsed_keys_len + 1,
            parsed_keys + Uint256.SIZE,
        );
    }
}
