from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_nn

from utils.bytes import felt_to_ascii

namespace Errors {
    const REVERT = 1;
    const EXCEPTIONAL_HALT = 2;

    func eth_validation_failed() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(eth_validation_failed_message);
        return (30, error);

        eth_validation_failed_message:
        dw 0x4b;  // K
        dw 0x61;  // a
        dw 0x6b;  // k
        dw 0x61;  // a
        dw 0x72;  // r
        dw 0x6f;  // o
        dw 0x74;  // t
        dw 0x3a;  // :
        dw 0x20;  //
        dw 0x65;  // e
        dw 0x74;  // t
        dw 0x68;  // h
        dw 0x20;  //
        dw 0x76;  // v
        dw 0x61;  // a
        dw 0x6c;  // l
        dw 0x69;  // i
        dw 0x64;  // d
        dw 0x61;  // a
        dw 0x74;  // t
        dw 0x69;  // i
        dw 0x6f;  // o
        dw 0x6e;  // n
        dw 0x20;  //
        dw 0x66;  // f
        dw 0x61;  // a
        dw 0x69;  // i
        dw 0x6c;  // l
        dw 0x65;  // e
        dw 0x64;  // d
    }

    func stateModificationError() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(state_modification_error_message);
        return (31, error);

        state_modification_error_message:
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 58;  // :
        dw 32;  //
        dw 83;  // S
        dw 116;  // t
        dw 97;  // a
        dw 116;  // t
        dw 101;  // e
        dw 77;  // M
        dw 111;  // o
        dw 100;  // d
        dw 105;  // i
        dw 102;  // f
        dw 105;  // i
        dw 99;  // c
        dw 97;  // a
        dw 116;  // t
        dw 105;  // i
        dw 111;  // o
        dw 110;  // n
        dw 69;  // E
        dw 114;  // r
        dw 114;  // r
        dw 111;  // o
        dw 114;  // r
    }

    func unknownOpcode() -> (error_len: felt, error: felt*) {
        alloc_locals;
        let (error) = get_label_location(unknown_opcode_error_message);
        return (22, error);

        unknown_opcode_error_message:
        dw 75;  // K'
        dw 97;  // a'
        dw 107;  // k'
        dw 97;  // a'
        dw 114;  // r'
        dw 111;  // o'
        dw 116;  // t'
        dw 58;  // :'
        dw 32;  // '
        dw 85;  // U'
        dw 110;  // n'
        dw 107;  // k'
        dw 110;  // n'
        dw 111;  // o'
        dw 119;  // w'
        dw 110;  // n'
        dw 79;  // O'
        dw 112;  // p'
        dw 99;  // c'
        dw 111;  // o'
        dw 100;  // d'
        dw 101;  // e'
    }

    func invalidJumpDestError() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(invalid_jump_dest_message);
        return (29, error);

        invalid_jump_dest_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 'i';
        dw 'n';
        dw 'v';
        dw 'a';
        dw 'l';
        dw 'i';
        dw 'd';
        dw 'J';
        dw 'u';
        dw 'm';
        dw 'p';
        dw 'D';
        dw 'e';
        dw 's';
        dw 't';
        dw 'E';
        dw 'r';
        dw 'r';
        dw 'o';
        dw 'r';
    }

    func callerNotKakarotAccount() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(caller_non_kakarot_error_message);
        return (49, error);

        caller_non_kakarot_error_message:
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 58;  // :
        dw 32;  //
        dw 99;  // c
        dw 97;  // a
        dw 108;  // l
        dw 108;  // l
        dw 101;  // e
        dw 114;  // r
        dw 32;  //
        dw 99;  // c
        dw 111;  // o
        dw 110;  // n
        dw 116;  // t
        dw 114;  // r
        dw 97;  // a
        dw 99;  // c
        dw 116;  // t
        dw 32;  //
        dw 105;  // i
        dw 115;  // s
        dw 32;  //
        dw 110;  // n
        dw 111;  // o
        dw 116;  // t
        dw 32;  //
        dw 97;  // a
        dw 32;  //
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 32;  //
        dw 65;  // A
        dw 99;  // c
        dw 99;  // c
        dw 111;  // o
        dw 117;  // u
        dw 110;  // n
        dw 116;  // t
    }

    func onlyViewEntrypoint() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(only_view_error_message);
        return (54, error);

        only_view_error_message:
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 58;  // :
        dw 32;  //
        dw 101;  // e
        dw 110;  // n
        dw 116;  // t
        dw 114;  // r
        dw 121;  // y
        dw 112;  // p
        dw 111;  // o
        dw 105;  // i
        dw 110;  // n
        dw 116;  // t
        dw 32;  //
        dw 115;  // s
        dw 104;  // h
        dw 111;  // o
        dw 117;  // u
        dw 108;  // l
        dw 100;  // d
        dw 32;  //
        dw 111;  // o
        dw 110;  // n
        dw 108;  // l
        dw 121;  // y
        dw 32;  //
        dw 98;  // b
        dw 101;  // e
        dw 32;  //
        dw 99;  // c
        dw 97;  // a
        dw 108;  // l
        dw 108;  // l
        dw 101;  // e
        dw 100;  // d
        dw 32;  //
        dw 105;  // i
        dw 110;  // n
        dw 32;  //
        dw 118;  // v
        dw 105;  // i
        dw 101;  // e
        dw 119;  // w
        dw 32;  //
        dw 109;  // m
        dw 111;  // o
        dw 100;  // d
        dw 101;  // e
    }

    func stackOverflow() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(stack_overflow_error_message);
        return (22, error);

        stack_overflow_error_message:
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 58;  // :
        dw 32;  //
        dw 83;  // S
        dw 116;  // t
        dw 97;  // a
        dw 99;  // c
        dw 107;  // k
        dw 79;  // O
        dw 118;  // v
        dw 101;  // e
        dw 114;  // r
        dw 102;  // f
        dw 108;  // l
        dw 111;  // o
        dw 119;  // w
    }

    func stackUnderflow() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(stack_underflow_error_message);
        return (23, error);

        stack_underflow_error_message:
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 58;  // :
        dw 32;  //
        dw 83;  // S
        dw 116;  // t
        dw 97;  // a
        dw 99;  // c
        dw 107;  // k
        dw 85;  // U
        dw 110;  // n
        dw 100;  // d
        dw 101;  // e
        dw 114;  // r
        dw 102;  // f
        dw 108;  // l
        dw 111;  // o
        dw 119;  // w
    }

    func outOfBoundsRead() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(out_of_bounds_read_error_message);
        return (24, error);

        out_of_bounds_read_error_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 'O';
        dw 'u';
        dw 't';
        dw 'O';
        dw 'f';
        dw 'B';
        dw 'o';
        dw 'u';
        dw 'n';
        dw 'd';
        dw 's';
        dw 'R';
        dw 'e';
        dw 'a';
        dw 'd';
    }

    func unknownPrecompile(address: felt) -> (error_len: felt, error: felt*) {
        alloc_locals;
        let (error) = alloc();
        assert [error + 0] = 75;  // K
        assert [error + 1] = 97;  // a
        assert [error + 2] = 107;  // k
        assert [error + 3] = 97;  // a
        assert [error + 4] = 114;  // r
        assert [error + 5] = 111;  // o
        assert [error + 6] = 116;  // t
        assert [error + 7] = 58;  // :
        assert [error + 8] = 32;  //
        assert [error + 9] = 85;  // U
        assert [error + 10] = 110;  // n
        assert [error + 11] = 107;  // k
        assert [error + 12] = 110;  // n
        assert [error + 13] = 111;  // o
        assert [error + 14] = 119;  // w
        assert [error + 15] = 110;  // n
        assert [error + 16] = 80;  // P
        assert [error + 17] = 114;  // r
        assert [error + 18] = 101;  // e
        assert [error + 19] = 99;  // c
        assert [error + 20] = 111;  // o
        assert [error + 21] = 109;  // m
        assert [error + 22] = 112;  // p
        assert [error + 23] = 105;  // i
        assert [error + 24] = 108;  // l
        assert [error + 25] = 101;  // e
        assert [error + 26] = 32;  // " "
        assert [error + 27] = '0' + address;  // convert uint address to str
        return (28, error);
    }

    func unauthorizedPrecompile() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(unauthorized_precompile_error_message);
        return (31, error);

        unauthorized_precompile_error_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 'u';
        dw 'n';
        dw 'a';
        dw 'u';
        dw 't';
        dw 'h';
        dw 'o';
        dw 'r';
        dw 'i';
        dw 'z';
        dw 'e';
        dw 'd';
        dw 'P';
        dw 'r';
        dw 'e';
        dw 'c';
        dw 'o';
        dw 'm';
        dw 'p';
        dw 'i';
        dw 'l';
        dw 'e';
    }

    func accountNotDeployed() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(account_not_deployed_error_message);
        return (27, error);

        account_not_deployed_error_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 'a';
        dw 'c';
        dw 'c';
        dw 'o';
        dw 'u';
        dw 'n';
        dw 't';
        dw 'N';
        dw 'o';
        dw 't';
        dw 'D';
        dw 'e';
        dw 'p';
        dw 'l';
        dw 'o';
        dw 'y';
        dw 'e';
        dw 'd';
    }

    func notImplementedPrecompile(address: felt) -> (error_len: felt, error: felt*) {
        alloc_locals;
        let (error) = alloc();
        assert [error + 0] = 75;  // K
        assert [error + 1] = 97;  // a
        assert [error + 2] = 107;  // k
        assert [error + 3] = 97;  // a
        assert [error + 4] = 114;  // r
        assert [error + 5] = 111;  // o
        assert [error + 6] = 116;  // t
        assert [error + 7] = 58;  // :
        assert [error + 8] = 32;  //
        assert [error + 9] = 78;  // N
        assert [error + 10] = 111;  // o
        assert [error + 11] = 116;  // t
        assert [error + 12] = 73;  // I
        assert [error + 13] = 109;  // m
        assert [error + 14] = 112;  // p
        assert [error + 15] = 108;  // l
        assert [error + 16] = 101;  // e
        assert [error + 17] = 109;  // m
        assert [error + 18] = 101;  // e
        assert [error + 19] = 110;  // n
        assert [error + 20] = 116;  // t
        assert [error + 21] = 101;  // e
        assert [error + 22] = 100;  // d
        assert [error + 23] = 80;  // P
        assert [error + 24] = 114;  // r
        assert [error + 25] = 101;  // e
        assert [error + 26] = 99;  // c
        assert [error + 27] = 111;  // o
        assert [error + 28] = 109;  // m
        assert [error + 29] = 112;  // p
        assert [error + 30] = 105;  // i
        assert [error + 31] = 108;  // l
        assert [error + 32] = 101;  // e
        assert [error + 33] = 32;  //

        if (address == 10) {
            assert [error + 34] = '1';
            assert [error + 35] = '0';
            return (36, error);
        }
        assert [error + 34] = '0' + address;
        return (35, error);
    }

    func invalidCairoSelector() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(invalid_cairo_selector_message);
        return (29, error);

        invalid_cairo_selector_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 'i';
        dw 'n';
        dw 'v';
        dw 'a';
        dw 'l';
        dw 'i';
        dw 'd';
        dw 'C';
        dw 'a';
        dw 'i';
        dw 'r';
        dw 'o';
        dw 'S';
        dw 'e';
        dw 'l';
        dw 'e';
        dw 'c';
        dw 't';
        dw 'o';
        dw 'r';
    }

    func balanceError() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(balance_error_message);
        return (40, error);

        balance_error_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 't';
        dw 'r';
        dw 'a';
        dw 'n';
        dw 's';
        dw 'f';
        dw 'e';
        dw 'r';
        dw ' ';
        dw 'a';
        dw 'm';
        dw 'o';
        dw 'u';
        dw 'n';
        dw 't';
        dw ' ';
        dw 'e';
        dw 'x';
        dw 'c';
        dw 'e';
        dw 'e';
        dw 'd';
        dw 's';
        dw ' ';
        dw 'b';
        dw 'a';
        dw 'l';
        dw 'a';
        dw 'n';
        dw 'c';
        dw 'e';
    }

    func addressCollision() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(address_collision_error_message);
        return (25, error);

        address_collision_error_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 'a';
        dw 'd';
        dw 'd';
        dw 'r';
        dw 'e';
        dw 's';
        dw 's';
        dw 'C';
        dw 'o';
        dw 'l';
        dw 'l';
        dw 'i';
        dw 's';
        dw 'i';
        dw 'o';
        dw 'n';
    }

    func outOfGas{range_check_ptr}(gas_left: felt, gas_used: felt) -> (
        error_len: felt, error: felt*
    ) {
        alloc_locals;
        let (error: felt*) = alloc();

        assert [error + 0] = 'K';
        assert [error + 1] = 'a';
        assert [error + 2] = 'k';
        assert [error + 3] = 'a';
        assert [error + 4] = 'r';
        assert [error + 5] = 'o';
        assert [error + 6] = 't';
        assert [error + 7] = ':';
        assert [error + 8] = ' ';
        assert [error + 9] = 'o';
        assert [error + 10] = 'u';
        assert [error + 11] = 't';
        assert [error + 12] = 'O';
        assert [error + 13] = 'f';
        assert [error + 14] = 'G';
        assert [error + 15] = 'a';
        assert [error + 16] = 's';
        assert [error + 17] = ' ';
        assert [error + 18] = 'l';
        assert [error + 19] = 'e';
        assert [error + 20] = 'f';
        assert [error + 21] = 't';
        assert [error + 22] = '=';

        let gas_left_in_range = is_nn(gas_left);
        if (gas_left_in_range == 0) {
            // Trim the useless left= part of the string
            return (17, error);
        }

        let gas_left_ascii_len = felt_to_ascii(error + 23, gas_left);

        assert [error + 23 + gas_left_ascii_len + 0] = ',';
        assert [error + 23 + gas_left_ascii_len + 1] = ' ';
        assert [error + 23 + gas_left_ascii_len + 2] = 'u';
        assert [error + 23 + gas_left_ascii_len + 3] = 's';
        assert [error + 23 + gas_left_ascii_len + 4] = 'e';
        assert [error + 23 + gas_left_ascii_len + 5] = 'd';
        assert [error + 23 + gas_left_ascii_len + 6] = '=';

        let gas_used_in_range = is_nn(gas_used);

        if (gas_used_in_range == 0) {
            return (23 + gas_left_ascii_len + 7, error);
        }

        let gas_used_ascii_len = felt_to_ascii(error + 23 + gas_left_ascii_len + 7, gas_used);

        return (23 + gas_left_ascii_len + 7 + gas_used_ascii_len, error);
    }

    func precompileInputError() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(precompile_input_error_message);
        return (27, error);

        precompile_input_error_message:
        dw 'P';
        dw 'r';
        dw 'e';
        dw 'c';
        dw 'o';
        dw 'm';
        dw 'p';
        dw 'i';
        dw 'l';
        dw 'e';
        dw ':';
        dw ' ';
        dw 'w';
        dw 'r';
        dw 'o';
        dw 'n';
        dw 'g';
        dw ' ';
        dw 'i';
        dw 'n';
        dw 'p';
        dw 'u';
        dw 't';
        dw '_';
        dw 'l';
        dw 'e';
        dw 'n';
    }

    func precompileFlagError() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(precompile_flag_error);
        return (22, error);

        precompile_flag_error:
        dw 'P';
        dw 'r';
        dw 'e';
        dw 'c';
        dw 'o';
        dw 'm';
        dw 'p';
        dw 'i';
        dw 'l';
        dw 'e';
        dw ':';
        dw ' ';
        dw 'f';
        dw 'l';
        dw 'a';
        dw 'g';
        dw ' ';
        dw 'e';
        dw 'r';
        dw 'r';
        dw 'o';
        dw 'r';
    }
}
