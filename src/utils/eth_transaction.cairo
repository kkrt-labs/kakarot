%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.math_cmp import is_not_zero, is_nn
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256

from kakarot.model import model
from kakarot.constants import Constants
from utils.rlp import RLP
from utils.utils import Helpers

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
        let (tx_items: RLP.Item*) = alloc();
        RLP.decode(tx_items, tx_data_len, tx_data);

        assert [tx_items].is_list = TRUE;
        let items_len = [tx_items].data_len;
        let items = cast([tx_items].data, RLP.Item*);

        // Pre eip-155 txs have 6 fields, post eip-155 txs have 9 fields
        // We check for both cases here, and do the remaining ones in the next if block
        assert items[0].is_list = FALSE;
        assert items[1].is_list = FALSE;
        assert items[2].is_list = FALSE;
        assert items[3].is_list = FALSE;
        assert items[4].is_list = FALSE;
        assert items[5].is_list = FALSE;

        let nonce = Helpers.bytes_to_felt(items[0].data_len, items[0].data);
        let gas_price = Helpers.bytes_to_felt(items[1].data_len, items[1].data);
        let gas_limit = Helpers.bytes_to_felt(items[2].data_len, items[2].data);
        let destination = Helpers.try_parse_destination_from_bytes(
            items[3].data_len, items[3].data
        );
        let amount = Helpers.bytes_to_uint256(items[4].data_len, items[4].data);
        let payload_len = items[5].data_len;
        let payload = items[5].data;

        // pre eip-155 txs have 6 fields, post eip-155 txs have 9 fields
        if (items_len == 6) {
            tempvar is_some = 0;
            tempvar chain_id = 0;
        } else {
            assert items_len = 9;
            assert items[6].is_list = FALSE;
            assert items[7].is_list = FALSE;
            assert items[8].is_list = FALSE;
            let chain_id = Helpers.bytes_to_felt(items[6].data_len, items[6].data);

            tempvar is_some = 1;
            tempvar chain_id = chain_id;
        }
        let is_some = [ap - 2];
        let chain_id = [ap - 1];

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
            chain_id=model.Option(is_some=is_some, value=chain_id),
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

        let (tx_items: RLP.Item*) = alloc();
        RLP.decode(tx_items, tx_data_len - 1, tx_data + 1);

        assert [tx_items].is_list = TRUE;
        let items_len = [tx_items].data_len;
        let items = cast([tx_items].data, RLP.Item*);

        assert items_len = 8;
        assert items[0].is_list = FALSE;
        assert items[1].is_list = FALSE;
        assert items[2].is_list = FALSE;
        assert items[3].is_list = FALSE;
        assert items[4].is_list = FALSE;
        assert items[5].is_list = FALSE;
        assert items[6].is_list = FALSE;
        assert items[7].is_list = TRUE;

        let chain_id = Helpers.bytes_to_felt(items[0].data_len, items[0].data);
        let nonce = Helpers.bytes_to_felt(items[1].data_len, items[1].data);
        let gas_price = Helpers.bytes_to_felt(items[2].data_len, items[2].data);
        let gas_limit = Helpers.bytes_to_felt(items[3].data_len, items[3].data);
        let destination = Helpers.try_parse_destination_from_bytes(
            items[4].data_len, items[4].data
        );
        let amount = Helpers.bytes_to_uint256(items[5].data_len, items[5].data);
        let payload_len = items[6].data_len;
        let payload = items[6].data;

        let (access_list: felt*) = alloc();
        let access_list_len = parse_access_list(
            access_list, items[7].data_len, cast(items[7].data, RLP.Item*)
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
            chain_id=model.Option(is_some=1, value=chain_id),
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

        let (tx_items: RLP.Item*) = alloc();
        RLP.decode(tx_items, tx_data_len - 1, tx_data + 1);

        assert [tx_items].is_list = TRUE;
        let items_len = [tx_items].data_len;
        let items = cast([tx_items].data, RLP.Item*);

        assert items_len = 9;
        assert items[0].is_list = FALSE;
        assert items[1].is_list = FALSE;
        assert items[2].is_list = FALSE;
        assert items[3].is_list = FALSE;
        assert items[4].is_list = FALSE;
        assert items[5].is_list = FALSE;
        assert items[6].is_list = FALSE;
        assert items[7].is_list = FALSE;
        assert items[8].is_list = TRUE;

        let chain_id = Helpers.bytes_to_felt(items[0].data_len, items[0].data);
        let nonce = Helpers.bytes_to_felt(items[1].data_len, items[1].data);
        let max_priority_fee_per_gas = Helpers.bytes_to_felt(items[2].data_len, items[2].data);
        let max_fee_per_gas = Helpers.bytes_to_felt(items[3].data_len, items[3].data);
        let gas_limit = Helpers.bytes_to_felt(items[4].data_len, items[4].data);
        let destination = Helpers.try_parse_destination_from_bytes(
            items[5].data_len, items[5].data
        );
        let amount = Helpers.bytes_to_uint256(items[6].data_len, items[6].data);
        let payload_len = items[7].data_len;
        let payload = items[7].data;
        let (access_list: felt*) = alloc();
        let access_list_len = parse_access_list(
            access_list, items[8].data_len, cast(items[8].data, RLP.Item*)
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
            chain_id=model.Option(is_some=1, value=chain_id),
        );
        return tx;
    }

    // @notice Returns the type of a tx, considering that legacy tx are type 0.
    // @dev This function checks if a raw transaction is a legacy Ethereum transaction by checking the transaction type
    // according to EIP-2718. If the transaction type is greater than or equal to 0xc0, it's a legacy transaction.
    // See https://eips.ethereum.org/EIPS/eip-2718#transactiontype-only-goes-up-to-0x7f
    // @param tx_data_len The len of the raw transaction data
    // @param tx_data The raw transaction data
    func get_tx_type{range_check_ptr}(tx_data_len: felt, tx_data: felt*) -> felt {
        with_attr error_message("tx_data_len is zero") {
            assert_not_zero(tx_data_len);
        }

        let type = [tx_data];
        let is_legacy = is_nn(type - 0xc0);
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
        let tx_type = get_tx_type(tx_data_len, tx_data);
        let is_supported = is_nn(2 - tx_type);
        with_attr error_message("Kakarot: transaction type not supported") {
            assert is_supported = TRUE;
        }
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
