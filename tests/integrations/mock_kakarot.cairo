%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
// Local dependencies
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    return ();
}

@view
func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(code_len: felt, code: felt*, calldata_len: felt, calldata: felt*) -> (
    stack_len: felt, stack: Uint256*, memory_len: felt, memory: felt*, gas_used: felt
) {
    alloc_locals;

    // Initialize toy stack
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 1));
    let stack: model.Stack* = Stack.push(stack, Uint256(4, 3));
    let stack_len = Stack.len(stack);

    // Initialize toy memory
    let memory: model.Memory* = Memory.init();
    let memory: model.Memory* = Memory.store(memory, Uint256(6, 5), 0);
    let memory: model.Memory* = Memory.store(memory, Uint256(8, 7), 32);

    let gas_used = 152259;

    return (
        stack_len=stack_len,
        stack=stack.elements,
        memory_len=memory.bytes_len,
        memory=memory.bytes,
        gas_used=gas_used,
    );
}

@external
func execute_at_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt, calldata_len: felt, calldata: felt*) -> (
    stack_len: felt, stack: Uint256*, memory_len: felt, memory: felt*, gas_used: felt
) {
    alloc_locals;
    // Initialize toy stack
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 1));
    let stack: model.Stack* = Stack.push(stack, Uint256(4, 3));
    let stack_len = Stack.len(stack);

    // Initialize toy memory
    let memory: model.Memory* = Memory.init();
    let memory: model.Memory* = Memory.store(memory, Uint256(6, 5), 0);
    let memory: model.Memory* = Memory.store(memory, Uint256(8, 7), 32);

    let gas_used = 152259;

    return (
        stack_len=stack_len,
        stack=stack.elements,
        memory_len=memory.bytes_len,
        memory=memory.bytes,
        gas_used=gas_used,
    );
}
