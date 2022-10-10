// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.uint256 import Uint256

namespace Helpers {
    func setup_python_defs() {
        %{
            import re, os, requests
            import array as arr
            import pprint

            MAX_LEN_FELT = 31
            os.environ.setdefault('DEBUG', 'True')
             
            def dump_array(array):
                #for key, val in memory.items():
                    #if key.segment_index == array.segment_index and key >= array:
                        #print(f"val: {val}")
                pprint.pprint(array)
                return

            def hex_string_to_int_array(text):
                res = []
                for i in range(0, len(text), 2):
                    res.append(int(text[i:i+2], 16))
                return res

            def cairo_bytes_to_hex(input):
                input_bytes = [val for key, val in memory.items() if key.segment_index == input.segment_index and key >= input]
                hex_str = byte_array_to_hex_string(input_bytes)
                return hex_str

            def py_get_len(array):
                i = 0
                for key, val in memory.items():
                    if key.segment_index == array.segment_index and key >= array:
                        i = i + 1
                return i

            def py_has_entries(array):
                i = 0
                for key, val in memory.items():
                    if key.segment_index == array.segment_index and key >= array:
                            return True
                return False

            def byte_array_to_hex_string(input):
                hex_str = ''.join(map(byte_to_hex, input))
                return hex_str

            def byte_to_hex(b):
                return f'{b:02x}'

            def str_to_felt(text):
                if len(text) > MAX_LEN_FELT:
                    raise Exception("Text length too long to convert to felt.")
                return int.from_bytes(text.encode(), "big")
             
            def felt_to_str(felt):
                length = (felt.bit_length() + 7) // 8
                return felt.to_bytes(length, byteorder="big").decode("utf-8")
             
            def str_to_felt_array(text):
                return [str_to_felt(text[i:i+MAX_LEN_FELT]) for i in range(0, len(text), MAX_LEN_FELT)]
             
            def uint256_to_int(uint256):
                return uint256[0] + uint256[1]*2**128
             
            def uint256(val):
                return (val & 2**128-1, (val & (2**256-2**128)) >> 128)
             
            def hex_to_felt(val):
                return int(val, 16)

            def post_debug(json):
                if os.environ.get('DEBUG') == 'True':
                    requests.post(url="http://localhost:8000", json=json)
        %}
        return ();
    }

    func has_entries(array: felt*) -> (res: felt) {
        alloc_locals;
        local res;
        %{
            if py_has_entries(ids.array):
                ids.res = 1
            else:
                ids.res = 0
        %}
        return (res=res);
    }

    func get_len(array: felt*) -> (res: felt) {
        alloc_locals;
        local res;
        %{ ids.res = py_get_len(ids.array) %}
        return (res=res);
    }

    func get_last(array: felt*) -> (res: felt) {
        alloc_locals;
        local res;
        %{
            if py_has_entries(ids.array):
                last_idx = py_get_len(ids.array) - 1
                ids.res = memory.get(ids.array + last_idx)
            else:
                ids.res = 0
        %}
        return (res=res);
    }

    func get_last_or_default(array: felt*, default_value: felt) -> (res: felt) {
        alloc_locals;
        local res;
        %{
            if py_has_entries(ids.array):
                last_idx = py_get_len(ids.array) - 1
                ids.res = memory[ids.array + last_idx]
            else:
                ids.res = ids.default_value
        %}
        return (res=res);
    }

    func to_uint256(val: felt) -> (res: Uint256) {
        return (res=Uint256(val, 0));
    }
}
