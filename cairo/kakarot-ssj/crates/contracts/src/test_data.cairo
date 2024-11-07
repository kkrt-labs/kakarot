// Smart Contract Bytecodes
// Counter Contract: 0.8.18+commit.87f61d96 with optimisation enabled
// Storage Contract: 0.8.20+commit.a1b79de6
//
// Original Counter Contract:
// contract Counter {
//     uint public count;
//     function get() public view returns (uint) { return count; }
//     function inc() public { count += 1; }
//     function dec() public { count -= 1; }
// }
//
// Original Storage Contract:
// contract Storage {
//     uint256 number;
//     function store(uint256 num) public { number = num; }
//     function retrieve() public view returns (uint256) { return number; }
// }

// Counter contract deployment bytecode
// Includes constructor and runtime initialization
pub fn deploy_counter_calldata() -> Span<u8> {
    [0x60, 0x80, 0x60, 0x40, 0x52, /* ... deployment bytecode ... */].span()
}

// Counter contract runtime bytecode
// Function selectors:
// - 0x371303c0: inc()  // Increments the counter by 1
// - 0x4e487b71: dec()  // Decrements the counter by 1
// - 0x06661abd: count() // Returns the current counter value
pub fn counter_evm_bytecode() -> Span<u8> {
    [0x60, 0x80, 0x60, 0x40, 0x52, /* ... runtime bytecode ... */].span()
}

// Storage contract runtime bytecode
// Function selectors:
// - 0x2e64cec1: retrieve() // Returns stored number
// - 0x60fe47b1: store()    // Stores new number
pub fn storage_evm_bytecode() -> Span<u8> {
    [0x60, 0x80, 0x60, 0x40, 0x52, /* ... storage bytecode ... */].span()
}

// EIP-2930 RLP encoded transaction
// format: 0x01 || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
// rlp decoding: ['0x01', '0x', '0x3b9aca00', '0x1e8480',
//               '0x0000006f746865725f65766d5f61646472657373', '0x', '0x371303c0', []]
pub fn eip_2930_rlp_encoded_counter_inc_tx() -> Span<u8> {
    [1, 235, 132, 75, 75, 82, 84, /* ... transaction data ... */].span()
}
