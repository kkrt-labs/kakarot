from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from utils.mpt.nibbles import Nibbles, NibblesImpl

namespace Node {
    const LEAF = 0;
    const EXTENSION = 1;
    const BRANCH = 2;
}

struct EncodedNode {
    data_len: felt,
    data: felt*,
}

struct Value {
    len: felt,
    data: felt*,
}

struct LeafNode {
    type: felt,
    key: Nibbles*,
    value: Value,
}

namespace LeafNodeImpl {
    const EVEN_FLAG = 0x20;
    const ODD_FLAG = 0x30;

    func init(key: Nibbles*, value_len: felt, value: felt*) -> LeafNode* {
        let value_ = Value(value_len, value);
        tempvar res = new LeafNode(Node.LEAF, key, value_);
        return res;
    }

    // TODO: keccak(rlp_encode(key)) if len(rlp_encoded) > 32
    func encode{range_check_ptr}(self: LeafNode*) -> EncodedNode* {
        alloc_locals;
        let (path_key_len, local unencoded) = NibblesImpl.encode_path(self.key, 1);
        memcpy(dst=unencoded + path_key_len, src=self.value.data, len=self.value.len);

        let (output) = alloc();
        %{
            import rlp
            from ethereum.crypto.hash import keccak256
            unencoded = serde.serialize_list(ids.unencoded, list_len=ids.path_key_len +ids.self.value.len)
            encoded = rlp.encode(unencoded)

            if len(encoded) < 32:
                segments.write_arg(ids.output, unencoded)
            else:
                segments.write_arg(ids.output, keccak256(encoded))
        %}

        tempvar leaf_encoding = new EncodedNode(
            data_len=path_key_len + self.value.len, data=output
        );

        // TODO: rlp encoding of value if required
        return leaf_encoding;
    }
}

struct ExtensionNode {
    type: felt,
    key: Nibbles*,
    child: EncodedNode*,
}

namespace ExtensionNodeImpl {
    const EVEN_FLAG = 0x00;
    const ODD_FLAG = 0x10;

    func init(key: Nibbles*, child: EncodedNode*) -> ExtensionNode* {
        tempvar res = new ExtensionNode(type=Node.EXTENSION, key=key, child=child);
        return res;
    }

    // TODO: keccak(rlp_encode(key)) if len(rlp_encoded) > 32
    func encode{range_check_ptr}(self: ExtensionNode*) -> EncodedNode* {
        alloc_locals;
        let (local path_key_len, local unencoded) = NibblesImpl.encode_path(self.key, 0);

        assert unencoded[path_key_len] = self.child.data_len;
        assert unencoded[path_key_len + 1] = cast(self.child.data, felt);

        let (output) = alloc();
        tempvar output_len;
        %{
            import rlp
            from ethereum.crypto.hash import keccak256
            key_bytes = serde.serialize_list(ids.unencoded, list_len=ids.path_key_len)
            child_bytes = serde.serialize_list(ids.unencoded+ids.path_key_len, item_scope="EncodedNode", list_len=1)[0]
            unencoded = [bytes(key_bytes), bytes(child_bytes)]
            encoded = rlp.encode(unencoded)

            if len(encoded) < 32:
                segments.write_arg(ids.output, unencoded)
                ids.output_len = len(unencoded)
            else:
                hashed_rlp = keccak256(encoded)
                segments.write_arg(ids.output, hashed_rlp)
                ids.output_len = len(hashed_rlp)
        %}

        tempvar extension_encoding = new EncodedNode(data_len=output_len, data=output);

        return extension_encoding;
    }
}

struct BranchNode {
    type: felt,
    children_len: felt,
    children: EncodedNode*,
    value: Value,
}

namespace BranchNodeImpl {
    func init(children: EncodedNode*, value_len: felt, value: felt*) -> BranchNode* {
        tempvar res = new BranchNode(
            type=Node.BRANCH, children_len=16, children=children, value=Value(value_len, value)
        );
        return res;
    }

    func encode{range_check_ptr}(self: BranchNode*) -> EncodedNode* {
        alloc_locals;
        let (unencoded) = alloc();
        let subnodes_len = 16;

        memcpy(dst=unencoded, src=self.children, len=self.children_len * EncodedNode.SIZE);
        assert unencoded[subnodes_len * EncodedNode.SIZE] = self.value.len;
        assert unencoded[subnodes_len * EncodedNode.SIZE + 1] = cast(self.value.data, felt);

        let (output) = alloc();
        tempvar output_len;
        %{
            import rlp
            from ethereum.crypto.hash import keccak256
            unencoded = [bytes(elem) for elem in serde.serialize_list(ids.unencoded, item_scope="EncodedNode", list_len=17*2)]
            encoded = rlp.encode(unencoded)

            if len(encoded) < 32:
                segments.write_arg(ids.output, unencoded)
                ids.output_len = len(unencoded)
            else:
                hashed_rlp = keccak256(encoded)
                segments.write_arg(ids.output, hashed_rlp)
                ids.output_len = len(hashed_rlp)
        %}

        tempvar branch_encoding = new EncodedNode(data_len=output_len, data=output);

        return branch_encoding;
    }

    func _encode_child(self: BranchNode*, index: felt, unencoded: felt*) {
        if (index == 16) {
            return ();
        }

        let child = self.children[index];
        let child_data_len = child.data_len;
        let child_data = child.data;

        if (child_data_len == 0) {
            let subnode = alloc();
            assert unencoded[index] = subnode;
            return _encode_child(self, index + 1, unencoded);
        }

        assert unencoded[index] = child_data;

        return _encode_child(self, index + 1, unencoded);
    }
}
