def to_uint(a):
    a = int(a)
    return (a & ((1 << 128) - 1), a >> 128)

def combine_ints(low: int, high: int) -> int:
     return (high << 128) + low

