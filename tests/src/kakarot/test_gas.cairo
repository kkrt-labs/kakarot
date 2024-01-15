%builtins range_check

from kakarot.gas import Gas

func test__memory_cost{range_check_ptr}() {
    tempvar words_len: felt;
    %{ ids.words_len = program_input["words_len"]; %}
    let cost = Gas.memory_cost(words_len);

    %{ segments.write_arg(output, [ids.cost]); %}
    return ();
}
