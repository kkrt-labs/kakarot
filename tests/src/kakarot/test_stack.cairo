%builtins range_check

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.uint256 import assert_uint256_eq

from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.stack import Stack

func test__init__should_return_an_empty_stack() {
    // When
    let stack = Stack.init();

    // Then
    assert stack.size = 0;
    return ();
}

func test__push__should_add_an_element_to_the_stack() {
    // Given
    let stack = Stack.init();

    // When
    Stack.push_uint128{stack=stack}(1);

    // Then
    assert stack.size = 1;
    return ();
}

func test__pop__should_pop_an_element_to_the_stack{range_check_ptr}() {
    // Given
    let stack = Stack.init();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    with stack {
        Stack.push(item_2);
        Stack.push(item_1);
        Stack.push(item_0);

        // When
        let (element) = Stack.pop();
    }

    // Then
    assert stack.size = 2;
    assert_uint256_eq([element], [item_0]);
    return ();
}

func test__pop__should_pop_N_elements_to_the_stack{range_check_ptr}() {
    alloc_locals;
    // Given
    let stack = Stack.init();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    with stack {
        Stack.push(item_2);
        Stack.push(item_1);
        Stack.push(item_0);

        // When
        let (local elements) = Stack.pop_n(3);
    }

    // Then
    assert_uint256_eq(elements[0], Uint256(1, 0));
    assert_uint256_eq(elements[1], Uint256(2, 0));
    assert_uint256_eq(elements[2], Uint256(3, 0));

    assert stack.size = 0;
    return ();
}

func test__peek__should_return_stack_at_given_index__when_value_is_0{range_check_ptr}() {
    // Given
    let stack = Stack.init();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    with stack {
        Stack.push(item_2);
        Stack.push(item_1);
        Stack.push(item_0);

        // When
        let (peek_0) = Stack.peek(0);
    }

    // Then
    assert_uint256_eq([peek_0], [item_0]);
    return ();
}

func test__peek__should_return_stack_at_given_index__when_value_is_1{range_check_ptr}() {
    // Given
    let stack = Stack.init();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    with stack {
        Stack.push(item_2);
        Stack.push(item_1);
        Stack.push(item_0);

        // When
        let (peek_1) = Stack.peek(1);
    }

    // Then
    assert_uint256_eq([peek_1], [item_1]);
    return ();
}

func test__swap__should_swap_2_stacks() -> model.Stack* {
    // Given
    alloc_locals;

    // Given
    let stack = Stack.init();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);
    tempvar item_3 = new Uint256(4, 0);

    with stack {
        Stack.push(item_3);
        Stack.push(item_2);
        Stack.push(item_1);
        Stack.push(item_0);

        // When
        Stack.swap_i(3);
    }

    return stack;
}
