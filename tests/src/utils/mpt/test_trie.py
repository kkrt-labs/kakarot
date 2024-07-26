from ethereum.cancun.trie import (
    bytes_to_nibble_list,
    encode_internal_node,
    patricialize,
)


def test_patricialize(cairo_run):
    key = bytes_to_nibble_list(b"doge")
    value = b"coins"
    expected = encode_internal_node(patricialize({key: value}, level=0))
    result = cairo_run("test__patricialize", objects={b"doge": value})

    assert bytes(result) == b"".join(e for e in expected)


def test_find_shortest_common_prefix(cairo_run):
    res = cairo_run(
        "test__find_shortest_common_prefix",
        objects={b"doge": b"coins"},
        substring=b"dog",
    )
    assert res == 3
