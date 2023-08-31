# Kakarot Components and Deployment

The entire Kakarot protocol is composed of 4 different contracts:

- Kakarot (Core)
- Contract Accounts
- Blockhash Registry

## Kakarot

The main Kakarot contract is located at:
[`./src/kakarot/kakarot.cairo`](../../src/kakarot/kakarot.cairo).

This is the core contract which is capable of executing decoded ethereum
transactions thanks to its `invoke` entrypoint.

Currently, Argent or Braavos accounts contracts don't work with Kakarot.
Consequently, the `deploy_externally_owned_account` entrypoint has been added to
let the owner of an Ethereum address get their corresponding starknet contract.

The mapping between EVM addresses and Starknet addresses of the deployed
contracts is stored as follows:

- each deployed contract has a `get_evm_address` entrypoint
- only the Kakarot contract deploys accounts and provides a
  `compute_starknet_address(evm_address)` entrypoint that returns the
  corresponding starknet address

For this latter computation to be account agnostic, Kakarot indeed uses a
transparent proxy.

## Contract Accounts

A _Contract Account_ is a StarkNet contract. However, it also acts as an
Ethereum style contract account within the Kakarot EVM. In isolation it is not
more than a StarkNet contract that stores some bytecode as well as some
key-value pairs which were assigned to it on creation. It is only addressable
via its StarkNet address and not an EVM address (which it is associated with
inside the Kakarot EVM).

## Externally Owned Account

Each Externally Owned Account in the EVM world has its counterpart in Starknet
by the mean of a specific account contract deployed by Kakarot.

This contract is a regular account contract in the Starknet sense with
`__validate__` and `__execute__` entrypoint. However, it does decode and
validate an EVM signed transaction and redirect it only to Kakarot. Further
development will allow the user to have one single Starknet account for both
Starknet native and Kakarot deployed dApp. For a general introduction to EVM
transactions, see
[the official doc](https://ethereum.org/en/developers/docs/transactions/).

## Blockhash Registry

The [BLOCKHASH](https://www.evm.codes/#40) opcode is a particular opcode that
requires the EVM to be aware of past blocks
([see also](https://ethresear.ch/t/the-curious-case-of-blockhash-and-stateless-ethereum/7304/7)).
Since this is not feasible from within Starknet, we deployed a block hash
registry contract on Starknet to make this data accessible on-chain.

The blockhash registry enables this by holding a `block_number -> block_hash`
mapping that admins can write to and Kakarot core can read from.

## Deploying Kakarot

With the above information in mind the Kakarot EVM can be deployed and
configured on StarkNet with the following steps:

1. Declare the account proxy, the contract account and the externally owner
   account contracts.

   - This generates class hashes which will be used by the core Kakarot contract
     to deploy _accounts_.

1. Deploy Kakarot (core), with the following constructor arguments:

   - StarkNet address of the owner/admin account that controls the Kakarot core
     contract.
   - Address of the ETH token contract (Which is also used as ether within the
     Kakarot EVM)
   - _Contract Account_ class hash.
   - _Externally Owned Account_ class hash.
   - _Account Proxy_ class hash.

1. Deploy Blockhash Registry

1. Store the addresses of the blockhash registry contracts in Kakarot core using
   `set_blockhash_registry`. This is required for Kakarot to access the last 256
   bock hashes.

This flow can be seen in the [deploy script](../../scripts/deploy_kakarot.py).
