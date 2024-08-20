import pytest
from ethereum.cancun.trie import (
    BranchNode,
    ExtensionNode,
    LeafNode,
    bytes_to_nibble_list,
    encode_internal_node,
)


@pytest.fixture(scope="module")
def default_leaf():
    """Leaf with the value "doge."""
    key = bytes_to_nibble_list(b"doge")
    value = b"coins"
    leaf = LeafNode(key, value)

    return b"".join([item for item in encode_internal_node(leaf)])


@pytest.fixture(scope="module")
def default_branch(default_leaf):
    """Branch with the value 'verb' and a leaf child 'doge'."""
    value = b"verb"
    children = [b""] * 16
    children[6 - 1] = default_leaf  # 6 is the value of the nibble, array is 0-indexed

    branch = BranchNode(children, value)

    encoding = encode_internal_node(branch)
    return (
        b"".join([item for item in encode_internal_node(branch)])
        if not isinstance(encoding, bytes)
        else encoding
    )


@pytest.fixture(scope="module")
def default_extension(default_branch):
    """Extension with the value 'verb' and a leaf child 'doge'."""
    extension = ExtensionNode(bytes_to_nibble_list(b"dog"), default_branch)

    encoding = encode_internal_node(extension)
    return (
        b"".join([item for item in encoding])
        if not isinstance(encoding, bytes)
        else encoding
    )


class TestNodes:
    class TestLeaf:
        def test__should_encode_leaf_even(self, default_leaf, cairo_run):
            key = b"doge"  # even leaf
            value = b"coins"

            result = cairo_run("test__leaf_encode", key=key, value=value)
            assert bytes(result) == default_leaf

        def test__iso(self, default_leaf, cairo_run):
            key = bytes.fromhex("646f6765")
            value = b"coins"

            result = cairo_run("test__leaf_encode", key=key, value=value)
            assert bytes(result) == default_leaf

        # TODO: keccak(RLP-encoded leaf) when len > 32

        # class TestExtension:
        def test__should_encode_extension_even(
            self, default_branch, default_extension, cairo_run
        ):
            key = b"dog"
            child = default_branch
            result = cairo_run("test__extension_encode", key=key, child=child)
            assert bytes(result) == default_extension

    class TestBranch:
        def test__should_encode_branch(self, default_branch, default_leaf, cairo_run):
            value = b"verb"
            children = [b""] * 16
            children[6 - 1] = (
                default_leaf  # 6 is the value of the nibble, array is 0-indexed
            )

            result = cairo_run("test__branch_encode", children=children, value=value)
            assert bytes(result) == default_branch
