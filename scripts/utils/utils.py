from textwrap import wrap


def hex_string_to_bytes_array(h: str):
    if len(h) % 2 != 0:
        raise ValueError(f"Provided string has an odd length {len(h)}")
    if h[:2] == "0x":
        h = h[2:]
    return [int(b, 16) for b in wrap(h, 2)]
