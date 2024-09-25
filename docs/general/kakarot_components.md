# Kakarot Components and Deployment

The entire Kakarot protocol is composed of 2 different kind of Starknet
contracts:

- Kakarot
- Accounts (EOA & Contract Accounts)

## Kakarot

The main Kakarot contract is located at:
[`./src/kakarot/kakarot.cairo`](../../src/kakarot/kakarot.cairo).

This is the core contract which is capable of executing ethereum
transactions thanks to its `eth_send_transaction`, `eth_send_raw_unsigned_tx` and `eth_call` entrypoints
(defined in [`./src/kakarot/eth_rpc.cairo`](../../src/kakarot/eth_rpc.cairo)).

Currently, Argent or Braavos accounts contracts don't work with Kakarot.

The mapping between EVM addresses and Starknet addresses of the deployed
contracts is stored as follows:

- each deployed contract has a `get_evm_address` entrypoint
- only the Kakarot contract deploys accounts and provides a
  `get_starknet_address(evm_address)` entrypoint that returns the corresponding
  starknet address

For this latter computation to be account agnostic, Kakarot indeed uses a
transparent proxy described in [Accounts](./accounts.md).

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

This flow can be seen in the
[deploy script](../../kakarot_scripts/deploy_kakarot.py).
