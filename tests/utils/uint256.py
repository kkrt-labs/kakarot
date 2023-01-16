def int_to_uint256(value):
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return low, high


def uint256_to_int(low, high):
    return low + high * 2**128
