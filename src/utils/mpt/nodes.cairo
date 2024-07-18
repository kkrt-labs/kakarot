
from utils.mpt.nibbles import Nibbles, NibblesImpl

namespace Node{
    const LEAF = 0;
    const EXTENSION = 1;
    const BRANCH = 2;
}

struct LeafNode {
    type: felt,
    key: Nibbles,
    value_len: felt,
    value: felt*,
}

namespace LeafNodeImpl{
    const EVEN_FLAG = 0x20;
    const ODD_FLAG = 0x30;

    func init(key: Nibbles, value_len: felt, value: felt*) -> LeafNode {
        return LeafNode(
            Node.LEAF,
            key,
            value_len,
            value,
        );
    }

    func encode(self: LeafNode) -> (
        
    )
}

struct ExtensionNode{
    type: felt,
}

namespace ExtensionNodeImpl{
    const EVEN_FLAG = 0x00;
    const ODD_FLAG = 0x10;
}

struct BranchNode {
    type: felt,
}

namespace BranchNodeImpl{

}
