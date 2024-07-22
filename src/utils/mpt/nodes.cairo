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

    func init(key: Nibbles*, value_len: felt, value: felt*) -> LeafNode {
        let value_ = Value(value_len, value);
        tempvar res = LeafNode(Node.LEAF, key, value_);
        return res;
    }

    // TODO: keccak(rlp_encode(key)) if len(rlp_encoded) > 32
    func encode{range_check_ptr}(self: LeafNode) -> EncodedNode* {
        alloc_locals;
        let (path_key_len, output) = NibblesImpl.encode_path(self.key, 1);
        memcpy(dst=output + path_key_len, src=self.value.data, len=self.value.len);
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

    func init(key: Nibbles*, child: EncodedNode*) -> ExtensionNode {
        tempvar res = ExtensionNode(type=Node.EXTENSION, key=key, child=child);
        return res;
    }

    // TODO: keccak(rlp_encode(key)) if len(rlp_encoded) > 32
    func encode{range_check_ptr}(self: ExtensionNode) -> EncodedNode* {
        alloc_locals;
        let (path_key_len, output) = NibblesImpl.encode_path(self.key, 0);
        memcpy(dst=output + path_key_len, src=self.child.data, len=self.child.data_len);
        tempvar extension_encoding = new EncodedNode(
            data_len=path_key_len + self.child.data_len, data=output
        );

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
        let (output) = alloc();
        let branches_encodings_len = _encode_child(self, 0, 0, output);

        memcpy(dst=output + branches_encodings_len, src=self.value.data, len=self.value.len);

        tempvar branch_encoding = new EncodedNode(
            data_len=branches_encodings_len + self.value.len, data=output
        );
        return branch_encoding;
    }

    func _encode_child(self: BranchNode*, index: felt, output_len: felt, output: felt*) -> felt {
        if (index == 16) {
            return output_len;
        }

        let child = self.children[index];
        let child_data_len = child.data_len;
        let child_data = child.data;

        if (child_data_len == 0) {
            return _encode_child(self, index + 1, output_len, output);
        }
        memcpy(dst=output + output_len, src=child.data, len=child_data_len);

        return _encode_child(self, index + 1, output_len + child_data_len, output);
    }
}
