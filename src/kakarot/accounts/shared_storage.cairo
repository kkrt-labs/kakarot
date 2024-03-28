%lang starknet

// We are intentionally causing a storage_slot collision here,
// by importing these variables in both `uninitialized_account` and `account_contract`.
// We are defining them here instead of in the account library, so as to not depend
// on content of the account library in uninitialized_account and ensure a fixed class hash.
@storage_var
func Account_evm_address() -> (evm_address: felt) {
}

@storage_var
func Account_kakarot_address() -> (kakarot_address: felt) {
}
