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

## Precompiles

There are 4 precompiles currently deployed on Kakarot:

- 0x75001: Whitelisted Cairo Precompile
- 0x75002: Whitelisted Cairo Message Precompile
- 0x75003: Multicall Precompile
- 0x75004: Cairo Call Precompile

### 0x75001: Whitelisted Cairo Precompile

This precompile allows any whitelisted caller to execute a Cairo contract. The
whitelisting is based on the address of the caller. This precompile can be
called using `DELEGATECALL` / `CALLCODE`. However, it cannot be called in a
nested DELEGATECALL scenario. As such, it should only be used by contracts that
have been thoroughly audited and are known to be secure.

Let's define three different flows to interact with the precompile, and the
expected behavior for each.

1. **Successful Flow** A participant Alice wants to interact with the
   `DualVMToken` contract. The `DualVMToken` contract has been whitelisted by
   the Kakarot team, meaning that it is authorized to call the `0x75001`
   precompile. Alice calls the `DualVMToken` contract to transfer Starknet
   Tokens, which will internally call the `0x75001` with a DELEGATECALL. Because
   DualVMToken is whitelisted, the call will pass validation and the Cairo
   contract will be executed. Alice's tokens are transferred to the recipient.

2. **Failed Flow 1** A participant Alice wants to interact with a random
   `Contract_X` contract. Alice calls `Contract_X`, which then calls the
   `DualVMToken` contract with a DELEGATECALL. The `DualVMToken` contract is
   whitelisted to call the `0x75001` precompile. However, it is forbidden to
   delegatecall into a contract that is whitelisted to call the `0x75001`
   precompile. To check this, we verify whether the `evm.message.address.evm` of
   the call is whitelisted. Here, because of the delegatecall behavior, this
   resolves to `Contract_X`, which is not whitelisted. The call will thus fail.

3. **Failed Flow 2** A participant Alice wants to interact with the
   `NonWhitelistedContract` contract, which is not whitelisted to call the
   `0x75001` precompile. Alice calls `NonWhitelistedContract`, which then calls
   the `0x75001` precompile with a DELEGATECALL. Because
   `NonWhitelistedContract` is not whitelisted, the call will fail validation
   and the transaction will be reverted. Alice's call to
   `NonWhitelistedContract` will therefore fail.

```mermaid
sequenceDiagram
    participant Alice
    participant Contract_X
    participant DualVMToken
    participant NonWhitelistedContract
    participant Precompile_75001

    rect rgb(200, 255, 200)
        Note over Alice,Precompile_75001: Successful Flow
        Alice->>DualVMToken: Call
        Note right of Alice: msg.sender = Alice<br/>msg.address.evm = DualVMToken
        DualVMToken->>Precompile_75001: delegatecall
        Note right of DualVMToken: msg.sender = Alice<br/>msg.address.evm = DualVMToken
        Note over Precompile_75001: Check if DualVMToken<br/>is whitelisted ✓
        Precompile_75001-->>DualVMToken: Success ✓
        DualVMToken-->>Alice: Success ✓
    end

    rect rgb(255, 200, 200)
        Note over Alice,Precompile_75001: Failed Flow 1 - Nested Delegatecall
        Alice->>Contract_X: Call
        Note right of Alice: msg.sender = Alice<br/>msg.address.evm = Contract_X
        Contract_X->>DualVMToken: delegatecall
        Note right of Contract_X: msg.sender = Alice<br/>msg.address.evm = Contract_X
        DualVMToken->>Precompile_75001: delegatecall
        Note over Precompile_75001: Fails: Precompile called<br/>during delegatecall ✗
        Precompile_75001-->>DualVMToken: Fail ✗
        DualVMToken-->>Contract_X: Fail ✗
        Contract_X-->>Alice: Fail ✗
    end

    rect rgb(255, 200, 200)
        Note over Alice,Precompile_75001: Failed Flow 2 - Non-whitelisted Contract
        Alice->>NonWhitelistedContract: Call
        Note right of Alice: msg.sender = Alice<br/>msg.address.evm = NonWhitelistedContract
        NonWhitelistedContract->>Precompile_75001: delegatecall
        Note right of NonWhitelistedContract: msg.sender = Alice<br/>msg.address.evm = NonWhitelistedContract
        Note over Precompile_75001: Check if NonWhitelistedContract<br/>is whitelisted ✗
        Precompile_75001-->>NonWhitelistedContract: Fail ✗
        NonWhitelistedContract-->>Alice: Fail ✗
    end
```

### 0x75002: Whitelisted Cairo Message Precompile

This precompile allows any whitelisted caller to execute a Cairo contract. The
whitelisting is based on the address of the caller. The purpose of the whitelist
is to ensure that messages sent to L1 are following a specific format (`to`,
`sender`, `data`).

```mermaid
sequenceDiagram
    participant Alice
    participant L2KakarotMessaging
    participant NonWhitelistedContract
    participant Precompile_75002

    rect rgb(200, 255, 200)
        Note over Alice,Precompile_75002: Successful Flow - Whitelisted Contract
        Alice->>L2KakarotMessaging: Call
        L2KakarotMessaging->>Precompile_75002: Execute Cairo Message
        Note over Precompile_75002: Check if L2KakarotMessaging<br/>is whitelisted ✓
        Note over Precompile_75002: Process message with:<br/>- to<br/>- sender<br/>- data
        Precompile_75002-->>L2KakarotMessaging: Success ✓
        L2KakarotMessaging-->>Alice: Success ✓
    end

    rect rgb(255, 200, 200)
        Note over Alice,Precompile_75002: Failed Flow - Non-whitelisted Contract
        Alice->>NonWhitelistedContract: Call
        NonWhitelistedContract->>Precompile_75002: Execute Cairo Message
        Note over Precompile_75002: Check if NonWhitelistedContract<br/>is whitelisted ✗
        Precompile_75002-->>NonWhitelistedContract: Fail ✗
        NonWhitelistedContract-->>Alice: Fail ✗
    end
```

### 0x75003: Multicall Precompile

Allows the caller to execute `n` Cairo calls in a single precompile call. This
precompile cannot be called with DELEGATECALL / CALLCODE. As such, it can be
used permissionlessly by any contract.

```mermaid
sequenceDiagram
    participant Alice
    participant Contract_X
    participant Precompile_75003
    participant CairoContract

    rect rgb(200, 255, 200)
        Note over Alice,CairoContract: Successful Flow - Direct Call
        Alice->>Precompile_75003: Direct Call with cairo_calls[]
        Note over Precompile_75003: Check: Not delegatecall ✓

        loop For each call in cairo_calls
            Precompile_75003->>Alice: execute_starknet_call
            Note right of Precompile_75003: Calls back to Alice's<br/>Starknet contract
            Alice->>CairoContract: Execute on Starknet
        end

        Precompile_75003-->>Alice: Success ✓
    end

    rect rgb(255, 200, 200)
        Note over Alice,CairoContract: Failed Flow - Delegatecall Attempt
        Alice->>Contract_X: Call
        Contract_X->>Precompile_75003: delegatecall
        Note over Precompile_75003: Check: Is delegatecall ✗<br/>Operation not permitted
        Precompile_75003-->>Contract_X: Fail ✗
        Contract_X-->>Alice: Fail ✗
    end
```

### 0x75004: Cairo Call Precompile

Same as `0x75003`, but for a single Cairo call.

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

The solidity part for the Cairo precompiles includes a library that allows
developers to interact with the Cairo precompiles. This library contains methods
to call a Cairo contract or class, either via `call` or `staticcall`.

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

> The full library can be found in
> [CairoLib.sol](../../solidity_contracts/src/CairoPrecompiles/CairoLib.sol)

It contains three functions, `callContract`, `staticcallContract` and
`libraryCall` that allow the user to call a Cairo contract or class deployed on
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

    #[external(v0)]
    pub fn get(self: @ContractState) -> u256 {
        self.counter.read()
    }

}
```

Calling this contract from an EVM contract would look like this:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {CairoLib} from "kakarot-lib/Cairolib.sol";

contract CairoCounterCaller  {
    /// @dev The cairo contract to call
    uint256 cairoCounter;

    /// @dev The cairo function selector to call - `inc`
    uint256 constant FUNCTION_SELECTOR_INC = uint256(keccak256("inc")) % 2**250;

    /// @dev The cairo function selector to call - `set_counter`
    uint256 constant FUNCTION_SELECTOR_SET_COUNTER = uint256(keccak256("set_counter")) % 2**250;

    /// @dev The cairo function selector to call - `get`
    uint256 constant FUNCTION_SELECTOR_GET = uint256(keccak256("get")) % 2**250;


    constructor(uint256 cairoContractAddress) {
        cairoCounter = cairoContractAddress;
    }

    function getCairoCounter() public view returns (uint256 counterValue) {
        // `get_counter` takes no arguments, so data is empty
        uint256[] memory data;
        bytes memory returnData = CairoLib.staticcallContract(cairoCounter, FUNCTION_SELECTOR_GET, data);

        // The return data is a 256-bit integer, so we can directly cast it to uint256
        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        // `inc` takes no arguments, so data is empty
        uint256[] memory data;
        CairoLib.callContract(cairoCounter, FUNCTION_SELECTOR_INC, data);
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
        CairoLib.callContract(cairoCounter, FUNCTION_SELECTOR_SET_COUNTER, data);
    }
}

```

Once deployed, the contract can be called to increment the counter in a Cairo
contract deployed at starknet address `cairoCounter`. The deployment address
will need to be communicated to Kakarot for the precompile to be whitelisted.

Internally, a new logic flow is implemented when processing message calls. If
the target address is the Cairo precompile address, we check if the code_address
of the message is whitelisted. If it is, we execute the Cairo contract. If it is
not, we revert the transaction.

To execute the Cairo contract, we need to convert the EVM calldata, expressed as
a `bytes`, to the expected Cairo calldata format `Array<felt252>`. In Solidity,
the `data` sent with the call will be represented as a `uint256[]`, where each
`uint256` element will be cast to a `felt252` in Cairo. Therefore, each 256-bit
word sequence in the EVM calldata must correspond to an element of at most 251
bits, which is Cairo's native field element size. If the value being passed is
less than 251 bits, it can be directly cast to a `felt252` in Cairo.

For example, consider the `setCairoCounter` function mentioned above. If we want
to increase the counter by 1, the `data` in Solidity would be:

```solidity
uint256[] memory data = new uint256[](2);
data[0] = 0;
data[1] = 1;
```

In this case, the Cairo expected input is a `u256`, which is composed of two
`felt` values. Therefore, the `newCounter` value is split into two values
smaller than the field element size, and the resulting `data` array is of
size 2.

Similarly, the return data of the Cairo contract is deserialized into a
`uint256[]` where each returned felt has been cast to a uint256.

> Note: It is left to the responsibility of the wrapper contract developer to
> ensure that the calldata is correctly serialized to match the Cairo contract's
> expected inputs, and to properly deserialize the return data into the expected
> type.
