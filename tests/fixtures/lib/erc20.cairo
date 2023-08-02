// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.6.1 (token/erc20/library.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq, uint256_not

from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.utils.constants.library import UINT8_MAX

//
// Events
//

@event
func Transfer(from_: felt, to: felt, value: Uint256) {
}

@event
func Approval(owner: felt, spender: felt, value: Uint256) {
}

//
// Storage
//

@storage_var
func ERC20_name() -> (name: felt) {
}

@storage_var
func ERC20_symbol() -> (symbol: felt) {
}

@storage_var
func ERC20_decimals() -> (decimals: felt) {
}

@storage_var
func ERC20_total_supply() -> (total_supply: Uint256) {
}

@storage_var
func ERC20_balances(account: felt) -> (balance: Uint256) {
}

@storage_var
func ERC20_allowances(owner: felt, spender: felt) -> (remaining: Uint256) {
}

namespace ERC20 {
    //
    // Initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        name: felt, symbol: felt, decimals: felt
    ) {
        ERC20_name.write(name);
        ERC20_symbol.write(symbol);
        with_attr error_message("ERC20: decimals exceed 2^8") {
            assert_le(decimals, UINT8_MAX);
        }
        ERC20_decimals.write(decimals);
        return ();
    }

    //
    // Public functions
    //

    func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
        return ERC20_name.read();
    }

    func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        symbol: felt
    ) {
        return ERC20_symbol.read();
    }

    func total_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        total_supply: Uint256
    ) {
        return ERC20_total_supply.read();
    }

    func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        decimals: felt
    ) {
        return ERC20_decimals.read();
    }

    func balance_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt
    ) -> (balance: Uint256) {
        return ERC20_balances.read(account);
    }

    func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, spender: felt
    ) -> (remaining: Uint256) {
        return ERC20_allowances.read(owner, spender);
    }

    func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        recipient: felt, amount: Uint256
    ) -> (success: felt) {
        let (sender) = get_caller_address();
        _transfer(sender, recipient, amount);
        return (success=TRUE);
    }

    func transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        sender: felt, recipient: felt, amount: Uint256
    ) -> (success: felt) {
        let (caller) = get_caller_address();
        _spend_allowance(sender, caller, amount);
        _transfer(sender, recipient, amount);
        return (success=TRUE);
    }

    func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        spender: felt, amount: Uint256
    ) -> (success: felt) {
        with_attr error_message("ERC20: amount is not a valid Uint256") {
            uint256_check(amount);
        }

        let (caller) = get_caller_address();
        _approve(caller, spender, amount);
        return (success=TRUE);
    }

    func increase_allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        spender: felt, added_value: Uint256
    ) -> (success: felt) {
        with_attr error("ERC20: added_value is not a valid Uint256") {
            uint256_check(added_value);
        }

        let (caller) = get_caller_address();
        let (current_allowance: Uint256) = ERC20_allowances.read(caller, spender);

        // add allowance
        with_attr error_message("ERC20: allowance overflow") {
            let (new_allowance: Uint256) = SafeUint256.add(current_allowance, added_value);
        }

        _approve(caller, spender, new_allowance);
        return (success=TRUE);
    }

    func decrease_allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        spender: felt, subtracted_value: Uint256
    ) -> (success: felt) {
        alloc_locals;
        with_attr error_message("ERC20: subtracted_value is not a valid Uint256") {
            uint256_check(subtracted_value);
        }

        let (caller) = get_caller_address();
        let (current_allowance: Uint256) = ERC20_allowances.read(owner=caller, spender=spender);

        with_attr error_message("ERC20: allowance below zero") {
            let (new_allowance: Uint256) = SafeUint256.sub_le(current_allowance, subtracted_value);
        }

        _approve(caller, spender, new_allowance);
        return (success=TRUE);
    }

    //
    // Internal
    //

    func _mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        recipient: felt, amount: Uint256
    ) {
        with_attr error_message("ERC20: amount is not a valid Uint256") {
            uint256_check(amount);
        }

        with_attr error_message("ERC20: cannot mint to the zero address") {
            assert_not_zero(recipient);
        }

        let (supply: Uint256) = ERC20_total_supply.read();
        with_attr error_message("ERC20: mint overflow") {
            let (new_supply: Uint256) = SafeUint256.add(supply, amount);
        }
        ERC20_total_supply.write(new_supply);

        let (balance: Uint256) = ERC20_balances.read(account=recipient);
        // overflow is not possible because sum is guaranteed to be less than total supply
        // which we check for overflow below
        let (new_balance: Uint256) = SafeUint256.add(balance, amount);
        ERC20_balances.write(recipient, new_balance);

        Transfer.emit(0, recipient, amount);
        return ();
    }

    func _burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: felt, amount: Uint256
    ) {
        with_attr error_message("ERC20: amount is not a valid Uint256") {
            uint256_check(amount);
        }

        with_attr error_message("ERC20: cannot burn from the zero address") {
            assert_not_zero(account);
        }

        let (balance: Uint256) = ERC20_balances.read(account);
        with_attr error_message("ERC20: burn amount exceeds balance") {
            let (new_balance: Uint256) = SafeUint256.sub_le(balance, amount);
        }

        ERC20_balances.write(account, new_balance);

        let (supply: Uint256) = ERC20_total_supply.read();
        let (new_supply: Uint256) = SafeUint256.sub_le(supply, amount);
        ERC20_total_supply.write(new_supply);
        Transfer.emit(account, 0, amount);
        return ();
    }

    func _transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        sender: felt, recipient: felt, amount: Uint256
    ) {
        with_attr error_message("ERC20: amount is not a valid Uint256") {
            uint256_check(amount);  // almost surely not needed, might remove after confirmation
        }

        with_attr error_message("ERC20: cannot transfer from the zero address") {
            assert_not_zero(sender);
        }

        let (sender_balance: Uint256) = ERC20_balances.read(account=sender);
        with_attr error_message("ERC20: transfer amount exceeds balance") {
            let (new_sender_balance: Uint256) = SafeUint256.sub_le(sender_balance, amount);
        }

        ERC20_balances.write(sender, new_sender_balance);

        // add to recipient
        let (recipient_balance: Uint256) = ERC20_balances.read(account=recipient);
        // overflow is not possible because sum is guaranteed by mint to be less than total supply
        let (new_recipient_balance: Uint256) = SafeUint256.add(recipient_balance, amount);
        ERC20_balances.write(recipient, new_recipient_balance);
        Transfer.emit(sender, recipient, amount);
        return ();
    }

    func _approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, spender: felt, amount: Uint256
    ) {
        with_attr error_message("ERC20: amount is not a valid Uint256") {
            uint256_check(amount);
        }

        with_attr error_message("ERC20: cannot approve from the zero address") {
            assert_not_zero(owner);
        }

        with_attr error_message("ERC20: cannot approve to the zero address") {
            assert_not_zero(spender);
        }

        ERC20_allowances.write(owner, spender, amount);
        Approval.emit(owner, spender, amount);
        return ();
    }

    func _spend_allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, spender: felt, amount: Uint256
    ) {
        alloc_locals;
        with_attr error_message("ERC20: amount is not a valid Uint256") {
            uint256_check(amount);  // almost surely not needed, might remove after confirmation
        }

        let (current_allowance: Uint256) = ERC20_allowances.read(owner, spender);
        let (infinite: Uint256) = uint256_not(Uint256(0, 0));
        let (is_infinite: felt) = uint256_eq(current_allowance, infinite);

        if (is_infinite == FALSE) {
            with_attr error_message("ERC20: insufficient allowance") {
                let (new_allowance: Uint256) = SafeUint256.sub_le(current_allowance, amount);
            }

            _approve(owner, spender, new_allowance);
            return ();
        }
        return ();
    }
}