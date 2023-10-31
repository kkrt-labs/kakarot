// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.uint256 import Uint256

from utils.dict import dict_keys, default_dict_copy, dict_values

@external
func test__dict_keys__should_return_keys{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let (local dict_start) = default_dict_new(0);
    let dict_ptr = dict_start;

    with dict_ptr {
        dict_write(0xa, 2);
        dict_write(0xb, 3);
        dict_write(0xb, 4);
        dict_read(0xb);
        dict_write(0xc, 5);
    }

    let (keys_len, keys) = dict_keys(dict_start, dict_ptr);

    assert keys_len = 5;
    assert [keys + 0] = 0xa;
    assert [keys + 1] = 0xb;
    assert [keys + 2] = 0xb;
    assert [keys + 3] = 0xb;
    assert [keys + 4] = 0xc;

    let (squashed_start, squashed_end) = default_dict_finalize(dict_start, dict_ptr, 0);

    let (keys_len, keys) = dict_keys(squashed_start, squashed_end);

    assert keys_len = 3;
    assert [keys + 0] = 0xa;
    assert [keys + 1] = 0xb;
    assert [keys + 2] = 0xc;

    return ();
}

@external
func test__default_dict_copy__should_return_copied_dict{range_check_ptr}() {
    let default_value = 0xdead;
    let (dict_ptr_start) = default_dict_new(default_value);
    let dict_ptr = dict_ptr_start;
    let key = 0x7e1;
    with dict_ptr {
        let (value) = dict_read(key);
        assert value = default_value;
        dict_write(key, 0xff);
        let (value) = dict_read(key);
        assert value = 0xff;
        dict_write(key + 1, 0xff + 1);
        dict_write(key + 2, 0xff + 2);
        dict_write(key + 3, 0xff + 3);
        dict_write(key + 4, 0xff + 4);
    }
    let (new_start, new_ptr) = default_dict_copy(dict_ptr_start, dict_ptr);

    assert new_ptr - new_start = DictAccess.SIZE * 5;

    let dict_ptr = new_ptr;
    with dict_ptr {
        let (value) = dict_read(key);
        assert value = 0xff;
        let (value) = dict_read(key + 1);
        assert value = 0xff + 1;
        let (value) = dict_read(key + 2);
        assert value = 0xff + 2;
        let (value) = dict_read(key + 3);
        assert value = 0xff + 3;
        let (value) = dict_read(key + 4);
        assert value = 0xff + 4;
        let (value) = dict_read(key + 10);
        assert value = default_value;
    }

    return ();
}

@external
func test__dict_values__should_return_values{range_check_ptr}() {
    alloc_locals;
    let (local dict_start) = default_dict_new(0);
    tempvar value_a = new Uint256(2, 0);
    tempvar value_tmp = new Uint256(3, 0);
    tempvar value_b = new Uint256(4, 0);
    tempvar value_c = new Uint256(5, 0);
    let dict_ptr = dict_start;

    with dict_ptr {
        dict_write(0xa, cast(value_a, felt));
        dict_write(0xb, cast(value_tmp, felt));
        dict_write(0xb, cast(value_b, felt));
        dict_read(0xb);
        dict_write(0xc, cast(value_c, felt));
    }

    let (values_len, values) = dict_values(dict_start, dict_ptr);

    assert values_len = 5;
    assert values[0] = value_a[0];
    assert values[1] = value_tmp[0];
    assert values[2] = value_b[0];
    assert values[3] = value_b[0];
    assert values[4] = value_c[0];

    let (squashed_start, squashed_end) = default_dict_finalize(dict_start, dict_ptr, 0);

    let (values_len, values) = dict_values(squashed_start, squashed_end);

    assert values_len = 3;
    assert values[0] = value_a[0];
    assert values[1] = value_b[0];
    assert values[2] = value_c[0];

    return ();
}
