import pytest
from ethereum.cancun.trie import (
    bytes_to_nibble_list,
    encode_internal_node,
    patricialize,
)


def _prepare_trie(object):
    return {bytes_to_nibble_list(key): value for key, value in object.items()}


@pytest.mark.parametrize(
    "object",
    [
        {b"doge": b"coins"},
        {b"do": b"verb", b"dog": b"bark"},
        {b"doge": b"coins", b"cat": b"meow", b"dog": b"bark", b"do": b"verb"},
    ],
)
def test_patricialize(cairo_run, object):
    prepared_object = _prepare_trie(object)
    final_node = patricialize(prepared_object, level=0)
    expected = encode_internal_node(final_node)
    result = cairo_run("test__patricialize", objects=prepared_object)

    if isinstance(expected, bytes):
        assert bytes(result) == expected
    else:
        assert bytes(result) == b"".join(e for e in expected)


def test_find_shortest_common_prefix(cairo_run):
    res = cairo_run(
        "test__find_shortest_common_prefix",
        objects={b"doge": b"coins"},
        substring=b"dog",
    )
    assert res == 3
