%lang starknet

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict import dict_write, dict_squash

// @dev Copy a default_dict
// @param start The pointer to the beginning of the dict
// @param self The pointer to the end of the dict
func default_dict_copy{range_check_ptr}(start: DictAccess*, end: DictAccess*) -> (
    DictAccess*, DictAccess*
) {
    alloc_locals;
    let (squashed_start, squashed_end) = dict_squash(start, end);

    if (squashed_start == squashed_end) {
        tempvar default_value = 0;
    } else {
        tempvar default_value = squashed_start.prev_value;
    }

    let (new_start) = default_dict_new(default_value);
    let new_ptr = new_start;
    let end_loop = squashed_end - squashed_start;

    if (end_loop == 0) {
        return (new_start, new_ptr);
    }

    loop:
    dict_write{dict_ptr=new_ptr}(key=squashed_start.key, new_value=squashed_start.new_value);
    let squashed_start = squashed_start + DictAccess.SIZE;
    tempvar end_loop = squashed_end - squashed_start;

    jmp loop if end_loop != 0;

    return (new_start, new_ptr);
}
