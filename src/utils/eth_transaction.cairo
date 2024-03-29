%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak, cairo_keccak_bigend
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256

from kakarot.model import model
from kakarot.constants import Constants
from kakarot.interfaces.interfaces import IKakarot
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
    ) -> model.EthTransaction* {
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
        alloc_locals;
        let (items: RLP.Item*) = alloc();
        RLP.decode(items, tx_data_len, tx_data);

        // the tx is a list of fields, hence first level RLP decoding
        // is a single item, which is indeed the sought list
        assert [items].is_list = TRUE;
        let sub_items_len = [items].data_len;
        let sub_items = cast([items].data, RLP.Item*);

        let nonce = Helpers.bytes_to_felt(sub_items[0].data_len, sub_items[0].data);
        let gas_price = Helpers.bytes_to_felt(sub_items[1].data_len, sub_items[1].data);
        let gas_limit = Helpers.bytes_to_felt(sub_items[2].data_len, sub_items[2].data);
        let destination = Helpers.try_parse_destination_from_bytes(
            sub_items[3].data_len, sub_items[3].data
        );
        let amount = Helpers.bytes_i_to_uint256(sub_items[4].data, sub_items[4].data_len);
        let payload_len = sub_items[5].data_len;
        let payload = sub_items[5].data;
        let chain_id = Helpers.bytes_to_felt(sub_items[6].data_len, sub_items[6].data);

        tempvar tx = new model.EthTransaction(
            signer_nonce=nonce,
            gas_limit=gas_limit,
            max_priority_fee_per_gas=gas_price,
            max_fee_per_gas=gas_price,
            destination=destination,
            amount=amount,
            payload_len=payload_len,
            payload=payload,
            access_list_len=0,
            access_list=cast(0, felt*),
            chain_id=chain_id,
        );
        return tx;
    }

    // @notice Decode an Ethereum transaction with optional access list
    // @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2930.md
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func decode_2930{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        tx_data_len: felt, tx_data: felt*
    ) -> model.EthTransaction* {
        alloc_locals;

        let (items: RLP.Item*) = alloc();
        RLP.decode(items, tx_data_len - 1, tx_data + 1);
        let sub_items_len = [items].data_len;
        let sub_items = cast([items].data, RLP.Item*);

        let chain_id = Helpers.bytes_to_felt(sub_items[0].data_len, sub_items[0].data);
        let nonce = Helpers.bytes_to_felt(sub_items[1].data_len, sub_items[1].data);
        let gas_price = Helpers.bytes_to_felt(sub_items[2].data_len, sub_items[2].data);
        let gas_limit = Helpers.bytes_to_felt(sub_items[3].data_len, sub_items[3].data);
        let destination = Helpers.try_parse_destination_from_bytes(
            sub_items[4].data_len, sub_items[4].data
        );
        let amount = Helpers.bytes_i_to_uint256(sub_items[5].data, sub_items[5].data_len);
        let payload_len = sub_items[6].data_len;
        let payload = sub_items[6].data;

        let (access_list: felt*) = alloc();
        let access_list_len = parse_access_list(
            access_list, sub_items[7].data_len, cast(sub_items[7].data, RLP.Item*)
        );
        tempvar tx = new model.EthTransaction(
            signer_nonce=nonce,
            gas_limit=gas_limit,
            max_priority_fee_per_gas=gas_price,
            max_fee_per_gas=gas_price,
            destination=destination,
            amount=amount,
            payload_len=payload_len,
            payload=payload,
            access_list_len=access_list_len,
            access_list=access_list,
            chain_id=chain_id,
        );
        return tx;
    }

    // @notice Decode an Ethereum transaction with fee market
    // @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1559.md
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func decode_1559{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        tx_data_len: felt, tx_data: felt*
    ) -> model.EthTransaction* {
        alloc_locals;

        let (items: RLP.Item*) = alloc();
        RLP.decode(items, tx_data_len - 1, tx_data + 1);
        // the tx is a list of fields, hence first level RLP decoding
        // is a single item, which is indeed the sought list
        assert [items].is_list = TRUE;
        let sub_items_len = [items].data_len;
        let sub_items = cast([items].data, RLP.Item*);

        let chain_id = Helpers.bytes_to_felt(sub_items[0].data_len, sub_items[0].data);
        let nonce = Helpers.bytes_to_felt(sub_items[1].data_len, sub_items[1].data);
        let max_priority_fee_per_gas = Helpers.bytes_to_felt(
            sub_items[2].data_len, sub_items[2].data
        );
        let max_fee_per_gas = Helpers.bytes_to_felt(sub_items[3].data_len, sub_items[3].data);
        let gas_limit = Helpers.bytes_to_felt(sub_items[4].data_len, sub_items[4].data);
        let destination = Helpers.try_parse_destination_from_bytes(
            sub_items[5].data_len, sub_items[5].data
        );
        let amount = Helpers.bytes_i_to_uint256(sub_items[6].data, sub_items[6].data_len);
        let payload_len = sub_items[7].data_len;
        let payload = sub_items[7].data;
        let (access_list: felt*) = alloc();
        let access_list_len = parse_access_list(
            access_list, sub_items[8].data_len, cast(sub_items[8].data, RLP.Item*)
        );
        tempvar tx = new model.EthTransaction(
            signer_nonce=nonce,
            gas_limit=gas_limit,
            max_priority_fee_per_gas=max_priority_fee_per_gas,
            max_fee_per_gas=max_fee_per_gas,
            destination=destination,
            amount=amount,
            payload_len=payload_len,
            payload=payload,
            access_list_len=access_list_len,
            access_list=access_list,
            chain_id=chain_id,
        );
        return tx;
    }

    // @notice Returns the type of a tx, considering that legacy tx are type 0.
    // @dev This function checks if a raw transaction is a legacy Ethereum transaction by checking the transaction type
    // according to EIP-2718. If the transaction type is greater than or equal to 0xc0, it's a legacy transaction.
    // See https://eips.ethereum.org/EIPS/eip-2718#transactiontype-only-goes-up-to-0x7f
    // @param tx_data The raw transaction data
    func get_tx_type{range_check_ptr}(tx_data: felt*) -> felt {
        let type = [tx_data];
        let is_legacy = is_le(0xc0, type);
        if (is_legacy != FALSE) {
            return 0;
        }
        return type;
    }

    // @notice Decode a raw Ethereum transaction
    // @param tx_data_len The length of the raw transaction data
    // @param tx_data The raw transaction data
    func decode{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        tx_data_len: felt, tx_data: felt*
    ) -> model.EthTransaction* {
        let tx_type = get_tx_type(tx_data);
        tempvar offset = 1 + 3 * tx_type;

        [ap] = bitwise_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = tx_data_len, ap++;
        [ap] = tx_data, ap++;
        jmp rel offset;
        call decode_legacy_tx;
        ret;
        call decode_2930;
        ret;
        call decode_1559;
        ret;
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
        chain_id: felt,
        r: Uint256,
        s: Uint256,
        v: felt,
        tx_data_len: felt,
        tx_data: felt*,
    ) {
        alloc_locals;
        let tx = decode(tx_data_len, tx_data);
        assert tx.signer_nonce = account_nonce;
        assert tx.chain_id = chain_id;

        // Note: here, the validate process assumes an ECDSA signature, and r, s, v field
        // Technically, the transaction type can determine the signature scheme.
        let tx_type = get_tx_type(tx_data);
        local y_parity: felt;
        if (tx_type == 0) {
            assert y_parity = (v - 2 * chain_id - 35);
        } else {
            assert y_parity = v;
        }

        let (local words: felt*) = alloc();
        let (words_len, last_word, last_word_num_bytes) = bytes_to_bytes8_little_endian(words, tx_data_len, tx_data);
        assert [words + words_len] = last_word;
        let words_len = words_len+1;

        let (keccak_ptr: felt*) = alloc();
        let keccak_ptr_start = keccak_ptr;
        with keccak_ptr {
            // From keccak/cairo_keccak_bigend doc:
            // > To use this function, split the input into words of 64 bits (little endian).
            // > Same as keccak, but outputs the hash in big endian representation.
            // > Note that the input is still treated as little endian.
            let (msg_hash) = cairo_keccak_bigend(inputs=words, n_bytes=tx_data_len);
            verify_eth_signature_uint256(
                msg_hash=msg_hash, r=r, s=s, v=y_parity, eth_address=address
            );
        }
        finalize_keccak(keccak_ptr_start, keccak_ptr);
        return ();
    }

    // @notice Recursively parses the RLP-decoded access list.
    // @dev the parsed format is [address, storage_keys_len, *[storage_keys], address, storage_keys_len, *[storage_keys]]
    // where keys_len is the number of storage keys, and each storage key takes 2 felts.
    // @param parsed_list The pointer to the next free cell in the parsed access list.
    // @param list_len The remaining length of the RLP-decoded access list to parse.
    // @param list_items The pointer to the current RLP-decoded access list item to parse.
    // @return The length of the serialized access list, expressed in total amount of felts in the list.
    func parse_access_list{range_check_ptr}(
        parsed_list: felt*, access_list_len: felt, access_list: RLP.Item*
    ) -> felt {
        alloc_locals;
        if (access_list_len == 0) {
            return 0;
        }

        // Address
        let address_item = cast(access_list.data, RLP.Item*);
        let address = Helpers.bytes20_to_felt(address_item.data);

        // List<StorageKeys>
        let keys_item = cast(access_list.data + RLP.Item.SIZE, RLP.Item*);
        let keys_len = keys_item.data_len;
        assert [parsed_list] = address;
        assert [parsed_list + 1] = keys_len;

        let keys = cast(keys_item.data, RLP.Item*);
        parse_storage_keys(parsed_list + 2, keys_len, keys);

        let serialized_len = parse_access_list(
            parsed_list + 2 + keys_len * Uint256.SIZE,
            access_list_len - 1,
            access_list + RLP.Item.SIZE,
        );
        return serialized_len + 2 + keys_len * Uint256.SIZE;
    }

    // @notice Recursively parses the RLP-decoded storage keys list of an address
    // and returns an array containing the parsed storage keys.
    // @dev the keys are stored in the parsed format [key_low, key_high, key_low, key_high]
    // @param parsed_keys The pointer to the next free cell in the parsed access list array.
    // @param keys_list_len The remaining length of the RLP-decoded storage keys list to parse.
    // @param keys_list The pointer to the current RLP-decoded storage keys list item to parse.
    func parse_storage_keys{range_check_ptr}(
        parsed_keys: felt*, keys_list_len: felt, keys_list: RLP.Item*
    ) {
        alloc_locals;
        if (keys_list_len == 0) {
            return ();
        }

        let key = Helpers.bytes32_to_uint256(keys_list.data);
        assert [parsed_keys] = key.low;
        assert [parsed_keys + 1] = key.high;

        parse_storage_keys(
            parsed_keys + Uint256.SIZE, keys_list_len - 1, keys_list + RLP.Item.SIZE
        );
        return ();
    }
}
