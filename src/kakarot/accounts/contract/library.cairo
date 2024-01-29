%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256, uint256_not
from starkware.starknet.common.syscalls import (
    StorageRead,
    StorageWrite,
    STORAGE_READ_SELECTOR,
    STORAGE_WRITE_SELECTOR,
    storage_read,
    storage_write,
    StorageReadRequest,
)
from starkware.cairo.common.memset import memset

from kakarot.interfaces.interfaces import IERC20, IKakarot

@storage_var
func bytecode_len_() -> (res: felt) {
}

@storage_var
func storage_(key: Uint256) -> (value: Uint256) {
}

@storage_var
func is_initialized_() -> (res: felt) {
}

@storage_var
func evm_address() -> (evm_address: felt) {
}

@storage_var
func nonce() -> (nonce: felt) {
}

// @title ContractAccount main library file.
// @notice This file contains the EVM smart contract account representation logic.
namespace ContractAccount {
    // Define the number of bytes per felt. Above 16, the following code won't work as it uses unsigned_div_rem
    // which is bounded by RC_BOUND = 2 ** 128 ~ uint128 ~ bytes16
    const BYTES_PER_FELT = 16;

    // @notice This function is used to initialize the smart contract account.
    func initialize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt, _evm_address) {
        let (is_initialized) = is_initialized_.read();
        assert is_initialized = 0;
        is_initialized_.write(1);
        Ownable.initializer(kakarot_address);
        evm_address.write(_evm_address);
        nonce.write(1);
        // Give infinite ETH transfer allowance to Kakarot
        let (native_token_address) = IKakarot.get_native_token(kakarot_address);
        let (infinite) = uint256_not(Uint256(0, 0));
        IERC20.approve(native_token_address, kakarot_address, infinite);
        return ();
    }

    // @return address The EVM address of the contract account
    func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        address: felt
    ) {
        let (address) = evm_address.read();
        return (address=address);
    }

    // @notice Store the bytecode of the contract.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func write_bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*) {
        // Access control check.
        Ownable.assert_only_owner();
        // Recursively store the bytecode.
        bytecode_len_.write(bytecode_len);
        internal.write_bytecode(bytecode_len=bytecode_len, bytecode=bytecode);
        return ();
    }

    // @notice This function is used to get the bytecode_len of the smart contract.
    // @return bytecode_len The length of the bytecode.
    func bytecode_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        res: felt
    ) {
        return bytecode_len_.read();
    }

    // @notice This function is used to get the bytecode of the smart contract.
    // @return bytecode_len The length of the bytecode.
    // @return bytecode The bytecode of the smart contract.
    func bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (bytecode_len: felt, bytecode: felt*) {
        alloc_locals;
        let (bytecode_len) = bytecode_len_.read();
        let (bytecode_) = internal.load_bytecode(bytecode_len);
        return (bytecode_len, bytecode_);
    }

    // @notice This function is used to read the storage at a key.
    // @param key The storage key, which is hash_felts(cast(Uint256, felt*)) of the Uint256 storage key.
    // @return value The store value.
    func storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(storage_addr: felt) -> (value: Uint256) {
        let (low) = storage_read(address=storage_addr + 0);
        let (high) = storage_read(address=storage_addr + 1);
        let value = Uint256(low, high);
        return (value,);
    }

    // @notice This function is used to write to the storage of the account.
    // @param key The storage key, which is hash_felts(cast(Uint256, felt*)) of the Uint256 storage key.
    // @param value The value to store.
    func write_storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(storage_addr: felt, value: Uint256) {
        // Access control check.
        Ownable.assert_only_owner();
        // Write State
        storage_write(address=storage_addr + 0, value=value.low);
        storage_write(address=storage_addr + 1, value=value.high);
        return ();
    }

    // @notice Selfdestruct whatever can be
    // @dev It's not possible to remove a contract in Starknet
    func selfdestruct{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() {
        alloc_locals;
        // Access control check.
        Ownable.assert_only_owner();
        nonce.write(0);
        is_initialized_.write(0);
        evm_address.write(0);

        // Bytecode could we erased more efficiently, there is no read to
        // initialize a new memory segment.
        let (bytecode_len) = bytecode_len_.read();
        let (local bytecode: felt*) = alloc();
        memset(bytecode, 0, bytecode_len);
        write_bytecode(bytecode_len, bytecode);

        bytecode_len_.write(0);

        // TODO: clean also the storage

        return ();
    }

    // @notice This function checks if the account was initialized.
    // @return is_initialized 1 if the account has been initialized 0 otherwise.
    func is_initialized{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (is_initialized: felt) {
        let is_initialized: felt = is_initialized_.read();
        return (is_initialized=is_initialized);
    }

    // @notice This function is used to read the nonce from storage
    // @return nonce The current nonce of the contract account
    func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        nonce: felt
    ) {
        return nonce.read();
    }

    // @notice This function set the account nonce
    func set_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_nonce: felt
    ) {
        // Access control check.
        Ownable.assert_only_owner();
        nonce.write(new_nonce);
        return ();
    }
}

namespace internal {
    // @notice Store the bytecode of the contract.
    // @param index The current free index in the bytecode_ storage.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func write_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytecode_len: felt, bytecode: felt*
    ) {
        alloc_locals;

        if (bytecode_len == 0) {
            return ();
        }

        tempvar syscall_ptr = syscall_ptr;
        tempvar bytecode_len = bytecode_len;
        static_assert syscall_ptr == [ap - 2];
        static_assert bytecode_len == [ap - 1];

        body:
        let syscall_ptr = cast([ap - 2], felt*);
        let bytecode_len = [ap - 1];
        let bytecode = cast([fp - 3], felt*);
        assert [cast(syscall_ptr, StorageWrite*)] = StorageWrite(
            selector=STORAGE_WRITE_SELECTOR,
            address=bytecode_len - 1,
            value=bytecode[bytecode_len - 1],
        );
        %{ syscall_handler.storage_write(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        tempvar syscall_ptr = syscall_ptr + StorageWrite.SIZE;
        tempvar bytecode_len = bytecode_len - 1;

        static_assert syscall_ptr == [ap - 2];
        static_assert bytecode_len == [ap - 1];
        jmp body if bytecode_len != 0;

        return ();
    }

    // @notice Load the bytecode of the contract in the specified array.
    // @param index The index in the bytecode.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func load_bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt) -> (bytecode: felt*) {
        alloc_locals;
        let (local bytecode: felt*) = alloc();

        if (bytecode_len == 0) {
            return (bytecode=bytecode);
        }

        tempvar syscall_ptr = syscall_ptr;
        tempvar bytecode_len = bytecode_len;
        static_assert syscall_ptr == [ap - 2];
        static_assert bytecode_len == [ap - 1];

        body:
        let syscall_ptr = cast([ap - 2], felt*);
        let bytecode_len = [ap - 1];
        let bytecode = cast([fp], felt*);

        let syscall = [cast(syscall_ptr, StorageRead*)];
        assert syscall.request = StorageReadRequest(
            selector=STORAGE_READ_SELECTOR, address=bytecode_len - 1
        );
        %{ syscall_handler.storage_read(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        let response = syscall.response;
        assert bytecode[bytecode_len - 1] = response.value;
        tempvar syscall_ptr = syscall_ptr + StorageRead.SIZE;
        tempvar bytecode_len = bytecode_len - 1;

        static_assert syscall_ptr == [ap - 2];
        static_assert bytecode_len == [ap - 1];
        jmp body if bytecode_len != 0;

        return (bytecode=bytecode);
    }
}
