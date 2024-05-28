# Cairo Precompiles

Kakarot zkEVM being a Starknet appchain, it is technically possible to run Cairo
Contracts on Kakarot. The purpose of this document is to explain the design
behind the Cairo precompiles, which are the Cairo contracts that are deployed on
Kakarot to provide additional functionality to the users.

## Requirements

From a developer / user perspective, the precompiles should be easy to interact
with from EVM contracts. As such, we need to provide a way to call the
precompiles from EVM contracts, and to return the results to the EVM contracts.
This involves:

- Converting the EVM calldata to Cairo inputs
- Converting the Cairo outputs to EVM return data

From a security perspective, the precompiles should _never_ produce Cairo errors
that would cause the transaction to revert. As we cannot catch contract call
errors in Cairo, we need to ensure that executing a `call_contract` syscall to a
precompile will never cause the transaction to revert, meaning that:

- The target Cairo addresses should always correspond to a deployed contract
- The selector of the Cairo function being called should always be present in
  the contract called
- The Cairo contract called should never _panic_

From these principles, we can derive the following design.

## Design

Interacting with the Cairo precompiles will only be done by calling specific EVM
contracts that have been whitelisted for this purpose. This ensures that the
Cairo precompiles are only called by contracts that have been reviewed and
approved regarding the security concerns mentioned above.

As such, the execution flow of an EVM message will be as follows:

```mermaid
flowchart TD
    A[Solidity contract] -->|CALL| B
    B{address type}
    B -->|EVM Contract| D[Execute contract]
    B -->|EVM Precompiles| E[Execute EVM precompile]
    B -->|Cairo Precompile| F{Whitelisted caller code?}
    F --> |yes| G[Call Cairo contract]
    F --> |no| H[Call fails]
```

## Implementation

The solidity part for the Cairo precompiles will include a library that allows
developers to interact with the Cairo precompiles. This library will contain
methods to call a Cairo contract or class, either via `call` or `staticcall`.

> Note: The behavior of high-level `calls` in solidity prevents calling
> precompiles directly. As such, the library will use the low-level `call` and
> `staticcall` opcodes to interact with these Cairo precompiles.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

library CairoLib {
    /// @dev The Cairo precompile contract's address.
    address constant CAIRO_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000075001;

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function callContract(
        uint256 contractAddress,
        uint256 functionSelector,
        uint256[] memory data
    ) internal returns (bytes memory returnData);

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallContract(
        uint256 contractAddress,
        uint256 functionSelector,
        uint256[] memory data
    ) internal view returns (bytes memory returnData);


    /// @dev Performs a low-level call to a Cairo class declared on the Starknet appchain.
    /// @param classHash The class hash of the Cairo class.
    /// @param functionSelector The function selector of the Cairo class function to be called.
    /// @param data The input data for the Cairo class function.
    /// @return returnData The return data from the Cairo class function.
    function libraryCall(
        uint256 classHash,
        uint256 functionSelector,
        uint256[] memory data
    ) internal view returns (bytes memory returnData);
}

```

It contains three functions, `callContract`, `staticcallContract` and
`libraryCall` that allows the user to call a Cairo contract or class deployed on
the Starknet appchain. The method takes three arguments:

- `contractAddress` or `classHash`: The address of the Cairo contract to call /
  class hash to call
- `functionSelector`: The selector of the function to call, as `sn_keccak` of
  the entrypoint name.
- `data`: The calldata to pass to the Cairo contract, as individual bytes.

Contract developers can use this library to interact with the Cairo precompiles.
Let's take an example of a contract that calls a Cairo contract to increment a
counter:

```rust
#[starknet::contract]
pub mod Counter {
    #[storage]
    struct Storage{
        counter: u256
    }

    #[external(v0)]
    pub fn inc(ref self: ContractState) {
        self.counter.write(self.counter.read() + 1);
    }

    #[external(v0)]
    pub fn set_counter(ref self: ContractState, new_counter: u256) {
        self.counter.write(new_counter);
    }

}
```

Calling this contract from an EVM contract would look like this:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./CairoLib.sol";

contract CairoCounterCaller  {
    /// @dev The cairo contract to call
    uint256 cairoCounterAddress;

    /// @dev The cairo function selector to call - `inc`
    uint256 constant FUNCTION_SELECTOR_INC = uint256(keccak256("inc")) % 2**250;

    /// @dev The cairo function selector to call - `set_counter`
    uint256 constant FUNCTION_SELECTOR_SET_COUNTER = uint256(keccak256("set_counter")) % 2**250;

    /// @dev The cairo function selector to call - `get`
    uint256 constant FUNCTION_SELECTOR_GET = uint256(keccak256("get")) % 2**250;


    constructor(uint256 cairoContractAddress) {
        cairoCounterAddress = cairoContractAddress;
    }

    function getCairoCounter() public view returns (uint256 counterValue) {
        // `get_counter` takes no arguments, so data is empty
        uint256[] memory data;
        bytes memory returnData = CairoLib.staticcallContract(cairoCounterAddress, FUNCTION_SELECTOR_GET, data);

        // The return data is a 256-bit integer, so we can directly cast it to uint256
        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        // `inc` takes no arguments, so data is empty
        uint256[] memory data;
        CairoLib.callContract(cairoCounterAddress, FUNCTION_SELECTOR_INC, data);
    }

    /// @notice Calls the Cairo contract to set its internal counter to an arbitrary value
    /// @dev The counter value is split into two 128-bit values to match the Cairo contract's expected inputs (u256 is composed of two u128s)
    /// @param newCounter The new counter value to set
    function setCairoCounter(uint256 newCounter) external{
        // The u256 input must be split into two u128 values to match the expected cairo input
        uint128 newCounterLow = uint128(newCounter);
        uint128 newCounterHigh = uint128(newCounter >> 128);

        uint256[] memory data = new uint256[](2);
        data[0] = uint256(newCounterLow);
        data[1] = uint256(newCounterHigh);
        CairoLib.callContract(cairoCounterAddress, FUNCTION_SELECTOR_SET_COUNTER, data);
    }
}

```

Once deployed, the contract can be called to increment the counter in a Cairo
contract deployed at starknet address `cairoCounterAddress`. The deployment
address will need to be communicated to Kakarot for the precompile to be
whitelisted.

Internally, a new logic flow is implemented when processing message calls. If
the target address is the Cairo precompile address, we check if the code_address
of the message is whitelisted. If it is, we execute the Cairo contract. If it is
not, we revert the transaction.

To execute the Cairo contract, we need to convert the EVM calldata, expressed as
a `bytes[]`, to the expected Cairo inputs, serialized to an `Array<felt252>`.
Each 256-bit word sequence in the EVM calldata must correspond to an element of
at most, 251 bit, Cairo's native field element. For example, consider the
`setCairoCounter` function above. The `newCounter` argument is 256 bits, and
thus split into two 128-bit values to match the expected Cairo input. If we want
to increase the counter by 1, the data sent would be `data = ["00" * 63 + "01"].

Similarly, the return data of the Cairo contract is deserialized into 32-bytes
words, and stored in the return data of the EVM call.

> Note: It is left to the responsibility of the wrapper contract developer to
> ensure that the calldata is correctly serialized to match the Cairo contract's
> expected inputs, and to properly deserialize the return data into the expected
> type.
