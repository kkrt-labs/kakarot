from textwrap import wrap
from typing import List


def hex_string_to_bytes_array(h: str):
    if len(h) % 2 != 0:
        raise ValueError(f"Provided string has an odd length {len(h)}")
    if h[:2] == "0x":
        h = h[2:]
    return [int(b, 16) for b in wrap(h, 2)]


def extract_memory_from_execute(result):
    mem = [0] * result.memory_bytes_len
    for i in range(0, len(result.memory_accesses), 3):
        k = result.memory_accesses[i]  # Word index.
        assert result.memory_accesses[i + 1] == 0  # Initial value.
        v = result.memory_accesses[i + 2]  # Final value.
        for j in range(16):
            if k * 16 + 15 - j < len(mem):
                mem[k * 16 + 15 - j] = v % 256
            else:
                assert v == 0
            v //= 256
    return mem


def extract_stack_from_execute(result):
    stack = [0] * int(result.stack_len / 2)
    for i in range(0, result.stack_len * 3, 6):
        k = result.stack_accesses[i]  # Word index.
        index = int(k / 2)
        assert result.stack_accesses[i + 1] == 0  # Initial value.
        high = result.stack_accesses[i + 2]  # Final value.
        assert result.stack_accesses[i + 4] == 0  # Initial value.
        low = result.stack_accesses[i + 5]  # Final value.
        stack[index] = 2**128 * high + low

    return stack
