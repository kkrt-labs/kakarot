from utils.utils import Helpers
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem

struct Nibbles {
    nibbles_len: felt,
    nibbles: felt*,
}

namespace NibblesImpl {
    func from_bytes{range_check_ptr}(bytes_len: felt, bytes: felt*) -> Nibbles* {
        alloc_locals;
        local nibbles_len = bytes_len * 2;
        let (local output: felt*) = alloc();

        if (nibbles_len == 0) {
            tempvar res = new Nibbles(nibbles_len, output);
            return res;
        }

        tempvar range_check_ptr = range_check_ptr;
        tempvar output = output;
        tempvar value = bytes[0];

        unpack_byte:
        let range_check_ptr = [ap - 3];
        let output = cast([ap - 2], felt*);
        let value = [ap - 1];
        let base = 0x10;
        let bound = 0x10;
        let (high, _) = unsigned_div_rem(value, base);
        assert [output] = high;
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        let output = output + 1;

        let nibbles_len = [fp];
        let output_start = cast([fp + 1], felt*);
        let count = output - output_start;
        let is_done = Helpers.is_zero(nibbles_len - count);
        jmp done if is_done != 0;

        let next_byte_index = count / 2;
        let bytes = cast([fp - 3], felt*);
        tempvar value = bytes[next_byte_index];
        let range_check_ptr = range_check_ptr + 1;
        [ap] = range_check_ptr, ap++;
        [ap] = output, ap++;
        [ap] = value, ap++;

        jmp unpack_byte;

        done:
        let nibbles_len = [fp];
        let nibbles = cast([fp + 1], felt*);

        tempvar res = new Nibbles(nibbles_len, nibbles);
        return res;
    }

    func pack_nibbles{range_check_ptr}(self: Nibbles*, bytes: felt*) -> felt {
        alloc_locals;
        let (local bytes_len, r) = unsigned_div_rem(self.nibbles_len, 2);
        with_attr error_message("nibbles_len must be even") {
            assert r = 0;
        }
        local range_check_ptr = range_check_ptr;

        if (self.nibbles_len == 0) {
            return 0;
        }

        tempvar count = 0;

        body:
        tempvar count = [ap - 1];
        let self = cast([fp - 4], Nibbles*);
        let bytes = cast([fp - 3], felt*);
        let nib_index = 2 * count;
        let nib_high = self.nibbles[nib_index];
        let nib_low = self.nibbles[nib_index + 1];

        let res = nib_high * 0x10 + nib_low;
        assert bytes[count] = res;

        let count = count + 1;
        let is_done = Helpers.is_zero(self.nibbles_len - (nib_index + 2));

        tempvar count = count;
        jmp done if is_done != 0;
        jmp body;

        done:
        let bytes = cast([fp - 3], felt*);
        let bytes_len = [fp];
        let range_check_ptr = [fp + 1];
        return bytes_len;
    }

    func pack_with_prefix{range_check_ptr}(self: Nibbles*, is_leaf: felt) -> (
        bytes_len: felt, bytes: felt*
    ) {
        alloc_locals;
        let (encoded) = alloc();
        let (_, is_odd) = unsigned_div_rem(self.nibbles_len, 2);

        // Case odd number of nibbles
        if (is_odd != 0) {
            let prefix = ((2 * is_leaf) + 1) * 16 + self.nibbles[0];
            assert encoded[0] = prefix;
            tempvar to_pack = new Nibbles(self.nibbles_len - 1, self.nibbles + 1);
            let bytes_len = NibblesImpl.pack_nibbles(to_pack, encoded + 1);
            let total_len = bytes_len + 1;
            return (total_len, encoded);
        }

        // Case even number of nibbles
        let prefix = 2 * is_leaf * 16;
        assert encoded[0] = prefix;
        let bytes_len = NibblesImpl.pack_nibbles(self, encoded + 1);
        let total_len = bytes_len + 1;
        return (total_len, encoded);
    }
}
