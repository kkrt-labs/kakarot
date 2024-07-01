struct Call {
    to: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*,
}

// Struct introduced to pass `[Call]` to __execute__
struct CallArray {
    to: felt,
    selector: felt,
    data_offset: felt,
    data_len: felt,
}

struct OutsideExecution {
    caller: felt,
    nonce: felt,
    execute_after: felt,
    execute_before: felt,
}
