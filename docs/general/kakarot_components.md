# Kakarot Components and Deployment

The entire Kakarot protocol is composed of 3 different kind of Starknet
contracts:

- Kakarot
- Accounts
  - EOA
  - Contract account

## Kakarot

The main Kakarot contract is located at:
[`./src/kakarot/kakarot.cairo`](../../src/kakarot/kakarot.cairo).

This is the core contract which is capable of executing decoded ethereum
transactions thanks to its `eth_send_transaction` and `eth_call` entrypoint.

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

## Accounts

The Ethereum protocol defines two kind of accounts:

- Externally Owned Accounts (EOA): accounts managed by a private-key and a
  wallet
- Contract Accounts (CA): accounts managed by their stored code (smart
  contracts)

Each of these account has a given Starknet contract class counterpart in
Kakarot.

In the EVM, each account (EOA or CA) is located at an address and has the
following properties:

```json
{
  "balance": "0x0ba1a9ce0ba1a9ce",
  "code": "0x6064640fffffffff2060005500",
  "nonce": "0x00",
  "storage": {
    "0x01": "0x02"
  }
}
```

Currently, Kakarot uses an external regular Starknet ERC20 contract for storing
the balances and consequently only the three other fields are stored in the
corresponding Starknet contracts. Though it doesn't bring any change from the
Kakarot point of view, it would allow Kakarot within Starknet to use Starknet
ETH (or STRK) as native token, removing the need for bridging it.

### Contract Accounts

It is basically used only as a storage backend for an EVM contract account. More
precisely, it uses regular Starknet `@storage_var` to store both the contract
bytecode and the contract storage (`SSTORE` and `SLOAD`).

### Externally Owned Account

This [contract](../../src/kakarot/accounts/eoa/externally_owned_account.cairo)
is an account in the Starknet sense, meaning that it defines the `__validate__`
and `__execute__` entrypoints and is used to send transactions from a wallet to
Kakarot. However, it doesn't use the `to` and `selector` fields but only the
`calldata` of a Starknet transaction to send the RLP encoded unsigned data. The
Ethereum signature is sent in the signature field. For a general introduction to
EVM transactions, see
[the official doc](https://ethereum.org/en/developers/docs/transactions/).

## Deploying Kakarot

With the above information in mind the Kakarot EVM can be deployed and
configured on Starknet with the following steps:

1. Declare the account proxy, the contract account and the externally owner
   account contracts.

   - This generates class hashes which will be used by the core Kakarot contract
     to deploy _accounts_.

1. Deploy Kakarot (core), with the following constructor arguments:

   - Starknet address of the owner/admin account that controls the Kakarot core
     contract.
   - Address of the ETH token contract (Which is also used as ether within the
     Kakarot EVM)
   - _Contract Account_ class hash.
   - _Externally Owned Account_ class hash.
   - _Account Proxy_ class hash.

This flow can be seen in the [deploy script](../../scripts/deploy_kakarot.py).
