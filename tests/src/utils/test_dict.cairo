// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_write, dict_read

from utils.dict import dict_keys

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
