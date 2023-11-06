// SPDX-License-Identifier: MIT

%lang starknet

@storage_var
func native_token_address() -> (res: felt) {
}

@storage_var
func blockhash_registry_address() -> (res: felt) {
}

@storage_var
func contract_account_class_hash() -> (value: felt) {
}

@storage_var
func externally_owned_account_class_hash() -> (res: felt) {
}

@storage_var
func account_proxy_class_hash() -> (res: felt) {
}

@storage_var
func deploy_fee() -> (deploy_fee: felt) {
}
