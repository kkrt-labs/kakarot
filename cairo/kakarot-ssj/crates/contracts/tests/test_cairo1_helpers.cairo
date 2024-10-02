use contracts::cairo1_helpers::Cairo1Helpers;
use utils::traits::integer::BytesUsedTrait;

#[test]
fn test_keccak() {
    // "Hello world!"
    // where:
    // 8031924123371070792 == int.from_bytes(b'Hello wo', 'little')
    // 560229490 == int.from_bytes(b'rld!', 'little')
    let input = array![8031924123371070792];
    let last_input_word: u64 = 560229490;
    let last_input_num_bytes = last_input_word.bytes_used();
    let state = Cairo1Helpers::contract_state_for_testing();

    let res = Cairo1Helpers::Helpers::keccak(
        @state, input, last_input_word, last_input_num_bytes.into()
    );

    assert_eq!(res, 0xecd0e108a98e192af1d2c25055f4e3bed784b5c877204e73219a5203251feaab);
}
