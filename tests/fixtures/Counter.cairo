%lang starknet

from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func Counter() -> (res: felt) {
}

@external
func inc{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (current_counter) = Counter.read();
    Counter.write(value=current_counter + 1);
    return ();
}

@view
func get{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (count: felt) {
    let (current_counter) = Counter.read();
    return (count=current_counter);
}
