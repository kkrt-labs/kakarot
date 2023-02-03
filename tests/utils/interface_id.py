from eth_utils import keccak


def get_interface_id():
    validate = keccak(
        text="__validate__(call_array_len: felt, call_array: ExternallyOwnedAccount.CallArray*, calldata_len: felt, calldata: felt*)"
    )
    validate_declare = keccak(text="__validate_declare__(class_hash: felt)")
    execute = keccak(
        text="__execute__(call_array_len: felt, call_array: ExternallyOwnedAccount.CallArray*, calldata_len: felt, calldata: felt*)"
    )
    get_evm_address = keccak(text="get_evm_address()")
    supports_interface = keccak(text="supports_interface(interface_id: felt)")
    is_valid_signature = keccak(
        text="is_valid_signature(hash_len: felt, hash: felt*, signature_len: felt, signature: felt*)"
    )
    return bytes(
        validate[i]
        ^ validate_declare[i]
        ^ execute[i]
        ^ get_evm_address[i]
        ^ supports_interface[i]
        ^ is_valid_signature[i]
        for i in range(4)
    )


print(get_interface_id().hex())
