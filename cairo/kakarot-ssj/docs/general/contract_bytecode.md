# Bytecode Storage Methods for Kakarot on Starknet

The bytecode is the compiled version of a contract, and it is what the Kakarot
EVM will execute when a contract is called. As Kakarot's state is embedded in the Starknet chain where it is deployed, contracts are not actually "deployed" on
Kakarot: instead, the EVM bytecode of the deployed contract is first executed,
and the returned data is then stored on-chain at a particular storage address
inside the Starknet contract corresponding to the contract's EVM address, whose
address is deterministically computed. The Kakarot EVM will be able to load this
bytecode by querying the storage of this Starknet contract when a user interacts
with its associated EVM address.

```mermaid
flowchart TD
    A[RPC call] --> B["eth_sendTransaction"]
    B --> |Check transaction type| C{Is deploy transaction?}
    C -- Yes --> D1[Execute initialization code]
    D1 -->|Set account code to return data| E1[Commit code to Starknet storage]
    E1 --> F1[Return deployed contract address]

    C -- No --> D2[Load account code from KakarotCore storage]
    D2 --> E2[Execute bytecode]
    E2 --> F2[Return execution result]
```

<span class="caption"> Transaction flow for deploy and execute transactions in
Kakarot</span>

There are several different ways to store the bytecode of a contract, and this
document will provide a quick overview of the different options, to choose the
most optimized one for this use case. The three main ways of handling contract
bytecode that were considered are:

- Storing the bytecode inside a contract's storage, using Ethereum as an L1 data
  availability layer.
- Storing the bytecode inside a contract's storage, using another data
  availability layer.
- Storing the bytecode directly in the contract code, not as a part of the
  contract's storage.

These three solutions all have their respective pros and cons, which will be
discussed in the following sections.

## Foreword: Data availability

In Validity Rollups, verifying the validity proof on L1 is sufficient to
guarantee the validity of a transaction execution on L2, without needing the
detailed transaction information to be sent to Ethereum.

However, to allow independent verification of the L2 chain's state and prevent
malicious operators from censoring or freezing the chain, some amount of data is
still required to be posted on a Data Availability (DA) layer. This makes the
Starknet state available even if the operator suddenly ceases operations. Data
availability ensures that users can always reconstruct the state of the rollup
by deriving its current state from the data posted by the rollup operator.

Without this, users would not be able to query an L2 contract's state if the
operator becomes unavailable. It provides users the security of knowing that if
the Starknet sequencer ever stops functioning, they can prove custody of their
funds using the data posted on the DA Layer. If that DA Layer is Ethereum
itself, then Ethereum's security guarantees are inherited.

## Different approaches to storing contract bytecode

### Using Ethereum as a DA Layer

Starknet currently uses Ethereum as its DA Layer. Each state update verified
on-chain is accompanied by the state diff between the previous and new state,
sent as calldata to Ethereum. This allows anyone observing Ethereum to
reconstruct the current state of Starknet. This security comes with a
significant price, as the publication of state diffs on Ethereum accounted for
[over 93% of the transaction fees paid on Starknet](https://community.starknet.io/t/volition-hybrid-data-availability-solution/97387).

The first choice when storing contract bytecode is to store it as a regular
variable in the contract account's storage, with its state diff posted on
Ethereum acting as the DA Layer.

In this case, the following data would reach L1:

- The Starknet address of the contract account
- The number of updated keys in that contract
- The keys to update
- The new values for these keys

On Starknet, the associated storage update fee for a transaction updating $n$
unique contracts and $m$ unique keys is:

$$ gas\ price \cdot c_w \cdot (2n + 2m) $$

where $c_w$ is the calldata cost (in gas) per 32-byte word.

When storing the EVM bytecode during deployment, one single contract (the
Starknet contract corresponding to the ContractAccount) would be updated, with
$m$ keys, where $m = (B / 31) + 2$ and $B$ is the size of the bytecode to store
(see [implementation details](./contract_bytecode.md#implementation-details)).

Considering a gas price of 34 gwei (average gas price in 2023, according to
[Etherscan](https://etherscan.io/chart/gasprice)), a calldata cost of 16 per
non-zero byte of calldata and the size of a typical ERC20 contract size of 2174
bytes, we would have $m = 72$. The associated storage update fee would be:

$$ fee = 34 \cdot (16 \cdot 32) \cdot (2 + 144) = 2,541,468 \text{ gwei}$$

This is the solution that was chosen for Kakarot; but there are other options
that could be considered presented thereafter.

### Using Starknet's volition mechanism

Volition is a hybrid data availability solution, providing the ability to choose
the data availability layer used for contract data. It allows users to choose
between using Ethereum as a DA Layer, or using Starknet itself as a DA Layer.
The security of state transitions, verified by STARK proofs on L1, is the same
for both L2 and L1 data availability modes. The difference is in the data
availability guarantees. When a state transition is verified on L1, its
correctness is ensured - however, the actual state of the L2 is not known on L1.
By posting state diffs on L1, the current state of Starknet can be reconstructed
from the beginning, but this has a significant cost as mentioned previously.

![Volition](volition.png)

Volition will allow developers to choose whether data will be stored in L1DA or
L2DA mode. This makes it possible to store data on L2, which is much less
expensive than storing it on L1. Depending on the data stored, it can be
advantageous if the cost of storing it on L1 is higher than its intrinsic value.
For example, a Volition-ERC20 token standard could have two balances - one on
L1DA for maximal security (major assets), and one on L2DA for lower
security/fees (small transactions).

In this case, the contract bytecode could be stored in a storage variable
settled on L2DA instead of L1DA. This would make Kakarot contract deployment
extremely cheap, by avoiding the cost of posting bytecode state diffs to
Ethereum.

#### Associated Risks

Some risks must be considered when using Volition. If a majority of malicious
sequencers collude and decide to not share an L2DA change with other
sequencers/full nodes, once the attack ends, the honest sequencers won't have
the data to reconstruct and compute the new L2DA root. In this case, not only is
the L2DA inaccessible, but any execution relying on L2DA will become unprovable,
since sequencers lack the correct L2DA state.

While unlikely, this remains a possibility to consider since L2DA is less secure
than L1DA. If it happened, the stored bytecode would be lost and the deployed
contract unexecutable.

> Note: While Volition could potentially store bytecode on L2DA in the future,
> this is not currently possible as Volition is not yet implemented on Starknet.

### Storing the EVM bytecode in the Cairo contract code

The last option is to store the EVM bytecode directly in the Cairo contract
code. This has the advantage of also being cheap, as this data is not stored on
L1.

On Starknet, there is a distinction between classes which is the definition of a
contract containing the Cairo bytecode, and contracts which are instances of
classes. When you declare a contract on Starknet, its information is added to
the
[Classes Tree](https://docs.starknet.io/documentation/architecture_and_concepts/Network_Architecture/starknet-state/#classes_tree),
which encodes information about the existing classes in the state of Starknet by
mapping class hashes to their compiled class hash. This class tree is itself a
part of the Starknet State Commitment, which is verified on Ethereum during
state updates. The class itself is stored in the nodes (both sequencers and full
nodes) of Starknet.

To implement this, a new class would need to be declared each time a
ContractAccount is deployed. This class would contain the contract's EVM
bytecode, exposed via a view function returning the bytecode. To do this, the
RPC would need to craft a custom Starknet contract containing the EVM bytecode
in its source code, and declare it on Starknet - not ideal for security and
practicality.

## Implementation details

Kakarot uses the first solution, storing bytecode in a storage variable
committed to Ethereum. This solution is the most secure one, as it relies on
Ethereum as a DA Layer, and thus inherits from Ethereum's security guarantees,
ensuring that the bytecode of the deployed contract is always available.

In Ethereum, a `deploy` transaction is identified by a null `to` address
(`Option::None`). The calldata sent to the KakarotCore contract when deploying a
new contract will be passed as an `Array<u8>` to the `eth_send_transaction`
entrypoint of the KakarotCore contract. This bytecode will then be packed 31
bytes at a time, reducing by 31 the size of the bytecode stored in storage,
which is the most expensive part of the transaction.

The contract storage related to a deployed contract is organized as:

```rust
struct Storage {
    bytecode: List<bytes31>,
    pending_word: felt252,
    pending_word_len: usize,
}
```

We use the `List` type from the
[Alexandria](https://github.com/keep-starknet-strange/alexandria/blob/main/src/storage/src/list.cairo)
library to store the bytecode, allowing us to store up to 255 31-bytes values
per `StorageBaseAddress`. Indeed, the current limitation on the maximal size of
a complex storage value is 256 field elements, where a field element is the
native data type of the Cairo VM. If we want to store more than 256 field
elements, which is the case for bytecode larger than 255 31-bytes values, which
represents 7.9kB, we need to split the data between multiple storage addresses.
The `List` type abstracts this process by automatically calculating the next
storage address to use, by applying poseidon hashes on the base storage address
of the list with the index of the segment to store the element in.

The logic behind this storage design is to make it very easy to load the
bytecode in the EVM when we want to execute a program. We will rely on the
ByteArray type, which is a type from the core library that we can use to access
individual byte indexes in an array of packed bytes31 values.

The rationale behind this structure is thoroughly documented in the core library
code. The variable stored in our contract's storage reflect the fields of the
ByteArray type. Once our bytecode is written in storage, we can simply load it
with

```rust
 let bytecode = ByteArray {
    data: self.bytecode.read().array(),
    pending_word: self.pending_word.read(),
    pending_word_len: self.pending_word_len.read()
};
```

After which the value of the bytecode at offset `i` can be accessed by simply
doing `bytecode[i]` when executing the bytecode instructions in the EVM - making
it convenient to iterate over.
