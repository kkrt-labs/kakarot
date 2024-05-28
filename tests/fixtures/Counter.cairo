%lang starknet

from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add

@storage_var
func Counter() -> (res: Uint256) {
}

@external
func inc{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (current_counter) = Counter.read();
    let (new_value, _) = uint256_add(current_counter, Uint256(1, 0));
    Counter.write(value=new_value);
    return ();
}

@external
func set_counter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_counter: Uint256
) {
    Counter.write(new_counter);
    return ();
}

@view
func get{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (count: Uint256) {
    let (current_counter) = Counter.read();
    return (count=current_counter);
}
