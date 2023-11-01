from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location

namespace Errors {
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

    func programCounterOutOfRange() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(pc_oor_error_message);
        return (33, error);

        pc_oor_error_message:
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 58;  // :
        dw 32;  //
        dw 80;  // P
        dw 114;  // r
        dw 111;  // o
        dw 103;  // g
        dw 114;  // r
        dw 97;  // a
        dw 109;  // m
        dw 67;  // C
        dw 111;  // o
        dw 117;  // u
        dw 110;  // n
        dw 116;  // t
        dw 101;  // e
        dw 114;  // r
        dw 79;  // O
        dw 117;  // u
        dw 116;  // t
        dw 79;  // O
        dw 102;  // f
        dw 82;  // R
        dw 97;  // a
        dw 110;  // n
        dw 103;  // g
        dw 101;  // e
    }

    func jumpToNonJumpdest() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(jumpdest_error_message);
        return (29, error);

        jumpdest_error_message:
        dw 75;  // K
        dw 97;  // a
        dw 107;  // k
        dw 97;  // a
        dw 114;  // r
        dw 111;  // o
        dw 116;  // t
        dw 58;  // :
        dw 32;  //
        dw 74;  // J
        dw 85;  // U
        dw 77;  // M
        dw 80;  // P
        dw 32;  //
        dw 116;  // t
        dw 111;  // o
        dw 32;  //
        dw 110;  // n
        dw 111;  // o
        dw 110;  // n
        dw 32;  //
        dw 74;  // J
        dw 85;  // U
        dw 77;  // M
        dw 80;  // P
        dw 68;  // D
        dw 69;  // E
        dw 83;  // S
        dw 84;  // T
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
        assert [error + 27] = address;  //
        return (28, error);
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
        assert [error + 34] = address;  //
        return (35, error);
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

    func outOfGas() -> (error_len: felt, error: felt*) {
        let (error) = get_label_location(oog_error_message);
        return (17, error);

        oog_error_message:
        dw 'K';
        dw 'a';
        dw 'k';
        dw 'a';
        dw 'r';
        dw 'o';
        dw 't';
        dw ':';
        dw ' ';
        dw 'o';
        dw 'u';
        dw 't';
        dw 'O';
        dw 'f';
        dw 'G';
        dw 'a';
        dw 's';
    }
}
