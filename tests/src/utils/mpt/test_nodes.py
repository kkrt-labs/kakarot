import pytest

# TODO(temp): the `encode_internal_node` import was patched to skip rlp encoding and keccak hashing
from ethereum.cancun.trie import (
    BranchNode,
    ExtensionNode,
    LeafNode,
    bytes_to_nibble_list,
    encode_internal_node,
)

# # TODO: use import instead - which encodes keccak(rlp) that we currently dont have
# def encode_internal_node(node: Any) -> Any:
#     """
#     Encode a Merkle Trie node into its RLP form. The RLP will then be
#     serialized into a `Bytes` and hashed unless it is less that 32 bytes
#     when serialized.

#     This function also accepts `None`, representing the absence of a node,
#     which is encoded to `b""`.

#     Parameters
#     ----------
#     node : Optional[InternalNode]
#         The node to encode.

#     Returns
#     -------
#     encoded : `rlp.RLP`
#         The node encoded as RLP.

#     """
#     unencoded: Any
#     if node is None:
#         unencoded = b""
#     elif isinstance(node, LeafNode):
#         unencoded = (
#             nibble_list_to_compact(node.rest_of_key, True),
#             node.value,
#         )
#     elif isinstance(node, ExtensionNode):
#         unencoded = (
#             nibble_list_to_compact(node.key_segment, False),
#             node.subnode,
#         )
#     elif isinstance(node, BranchNode):
#         unencoded = node.subnodes + [node.value]
#     else:
#         raise AssertionError(f"Invalid internal node type {type(node)}!")

#     return unencoded


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

    return b"".join([item for item in encode_internal_node(branch)])


@pytest.fixture(scope="module")
def default_extension(default_branch):
    """Extension with the value 'verb' and a leaf child 'doge'."""
    extension = ExtensionNode(bytes_to_nibble_list(b"dog"), default_branch)

    return b"".join([item for item in encode_internal_node(extension)])


class TestNodes:
    class TestLeaf:
        def test__should_encode_leaf_even(self, cairo_run):
            key = b"do"
            path_key = bytes.fromhex("20") + key  # odd leaf
            value = b"verb"
            expected = path_key + value

            result = cairo_run("test__leaf_encode", key=key, value=value)
            assert bytes(result) == expected

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
        def test__should_encode_branch(self, default_branch, cairo_run):
            value = b"verb"
            children = [b""] * 16
            leaf_child = bytes.fromhex("20") + b"doge" + b"coins"
            children[6 - 1] = (
                leaf_child  # 6 is the value of the nibble, array is 0-indexed
            )

            result = cairo_run("test__branch_encode", children=children, value=value)
            assert bytes(result) == default_branch
