from functools import cache

from eth_utils.address import to_checksum_address
from starkware.cairo.lang.compiler.ast.cairo_types import (
    TypeFelt,
    TypePointer,
    TypeTuple,
)


@cache
def get_struct_scope(runner, struct_name):
    scoped_names = [
        name
        for name in runner.program.identifiers.as_dict()
        if f"model.{struct_name}" in str(name)
    ]
    if len(scoped_names) != 1:
        raise ValueError(
            f"Expected one struct named {struct_name}, found {scoped_names}"
        )
    return runner.program.identifiers.get_by_full_name(scoped_names[0])


class Serde:
    def __init__(self, runner):
        self.runner = runner
        self.memory = runner.segments.memory

    def read_segment(self, segment_ptr):
        segment_size = self.runner.segments.get_segment_size(segment_ptr.segment_index)
        return [self.memory.get(segment_ptr + i) for i in range(segment_size)]

    def serialize_address(self, address_ptr):
        address_scope = get_struct_scope(self.runner, "Address")
        return {
            "starknet": f'0x{self.memory.get(address_ptr + address_scope.members["starknet"].offset):064x}',
            "evm": to_checksum_address(
                f'0x{self.memory.get(address_ptr + address_scope.members["evm"].offset):040x}'
            ),
        }

    def serialize_dict(self, dict_ptr):
        dict_ptr = dict_ptr - dict_ptr.offset
        dict_size = self.runner.segments.get_segment_size(dict_ptr.segment_index)
        output = {}
        for dict_index in range(0, dict_size, 3):
            key = self.memory.get(dict_ptr + dict_index)
            value_ptr = self.memory.get(dict_ptr + dict_index + 2)
            output[key] = self.serialize_uint256(value_ptr) if value_ptr != 0 else ""
        return output

    def serialize_uint256(self, uint256_ptr):
        return hex(
            self.memory.get(uint256_ptr) + self.memory.get(uint256_ptr + 1) * 2**128
        )

    def serialize_account(self, account_ptr):
        account_scope = get_struct_scope(self.runner, "Account")
        address_ptr = self.memory.get(
            account_ptr + account_scope.members["address"].offset
        )
        code_ptr = self.memory.get(account_ptr + account_scope.members["code"].offset)
        storage_ptr = self.memory.get(
            account_ptr + account_scope.members["storage_start"].offset
        )
        balance_ptr = self.memory.get(
            account_ptr + account_scope.members["balance"].offset
        )
        return {
            "address": self.serialize_address(address_ptr),
            "code": self.read_segment(code_ptr),
            "storage": self.serialize_dict(storage_ptr),
            "nonce": self.memory.get(
                account_ptr + account_scope.members["nonce"].offset
            ),
            "balance": self.serialize_uint256(balance_ptr),
            "selfdestruct": self.memory.get(
                account_ptr + account_scope.members["selfdestruct"].offset
            ),
        }

    def serialize_accounts(self, accounts_ptr):
        accounts_ptr = accounts_ptr - accounts_ptr.offset
        accounts_size = self.runner.segments.get_segment_size(
            accounts_ptr.segment_index
        )
        accounts = {}
        for account_index in range(0, accounts_size, 3):
            key = self.memory.get(accounts_ptr + account_index)
            account_ptr = self.memory.get(accounts_ptr + account_index + 2)
            accounts[key] = (
                self.serialize_account(account_ptr) if account_ptr != 0 else {}
            )
        return accounts

    def serialize_event(self, event_ptr):
        event_scope = get_struct_scope(self.runner, "Event")
        return {
            "topics": self.read_segment(
                event_ptr + event_scope.members["topics"].offset
            ),
            "data": self.read_segment(event_ptr + event_scope.members["data"].offset),
        }

    def serialize_transfer(self, transfer_ptr):
        transfer_scope = get_struct_scope(self.runner, "transfer")
        return {
            "sender": self.serialize_address(
                transfer_ptr + transfer_scope.members["sender"].offset
            ),
            "recipient": self.serialize_address(
                transfer_ptr + transfer_scope.members["recipient"].offset
            ),
            "amount": self.serialize_uint256(
                transfer_ptr + transfer_scope.members["amount"].offset
            ),
        }

    def serialize_list(self, segment_ptr, item_size, item_serialize):
        segment_ptr = segment_ptr - segment_ptr.offset
        segment_size = self.runner.segments.get_segment_size(segment_ptr.segment_index)
        output = []
        for i in range(0, segment_size, item_size):
            item_ptr = self.memory.get(segment_ptr + i)
            output.append(item_serialize(item_ptr))
        return output

    def serialize_state(self, state_ptr):
        state_scope = get_struct_scope(self.runner, "State")
        event_scope = get_struct_scope(self.runner, "Event")
        transfer_scope = get_struct_scope(self.runner, "Transfer")

        accounts_ptr = self.memory.get(
            state_ptr + state_scope.members["accounts_start"].offset
        )
        events_ptr = self.memory.get(state_ptr + state_scope.members["events"].offset)
        transfers_ptr = self.memory.get(
            state_ptr + state_scope.members["transfers"].offset
        )
        return {
            "accounts": self.serialize_accounts(accounts_ptr),
            "events": self.serialize_list(
                events_ptr, event_scope.size, self.serialize_event
            ),
            "transfers": self.serialize_list(
                transfers_ptr, transfer_scope.size, self.serialize_transfer
            ),
        }

    def serialize_eth_transaction(self, tx_ptr):
        tx_scope = get_struct_scope(self.runner, "EthTransaction")
        payload_ptr = self.memory.get(tx_ptr + tx_scope.members["payload"].offset)
        payload_len = self.memory.get(tx_ptr + tx_scope.members["payload_len"].offset)
        access_list_ptr = self.memory.get(
            tx_ptr + tx_scope.members["access_list"].offset
        )
        access_list_len = self.memory.get(
            tx_ptr + tx_scope.members["access_list_len"].offset
        )
        return {
            "signer_nonce": self.memory.get(
                tx_ptr + tx_scope.members["signer_nonce"].offset
            ),
            "gas_limit": self.memory.get(tx_ptr + tx_scope.members["gas_limit"].offset),
            "max_priority_fee_per_gas": self.memory.get(
                tx_ptr + tx_scope.members["max_priority_fee_per_gas"].offset
            ),
            "max_fee_per_gas": self.memory.get(
                tx_ptr + tx_scope.members["max_fee_per_gas"].offset
            ),
            "destination": {
                "is_some": self.memory.get(
                    tx_ptr + tx_scope.members["destination"].offset
                ),
                "value": to_checksum_address(
                    f'0x{self.memory.get(tx_ptr + tx_scope.members["destination"].offset + 1):040x}'
                ),
            },
            "amount": self.serialize_uint256(
                tx_ptr + tx_scope.members["amount"].offset
            ),
            "payload": "0x" + bytes(self.read_segment(payload_ptr)[:payload_len]).hex(),
            "access_list": self.read_segment(access_list_ptr)[:access_list_len]
            if access_list_len > 0
            else [],
            "chain_id": self.memory.get(tx_ptr + tx_scope.members["chain_id"].offset),
        }

    def serialize_stack(self, stack_ptr):
        stack_scope = get_struct_scope(self.runner, "Stack")
        dict_ptr = self.memory.get(
            stack_ptr + stack_scope.members["dict_ptr_start"].offset
        )
        stack_dict = self.serialize_dict(dict_ptr)
        stack_size = self.memory.get(stack_ptr + stack_scope.members["size"].offset)
        return [stack_dict[i] for i in range(stack_size)]

    def serialize_scope(self, scope, scope_ptr):
        if scope.path[-1] == "State":
            return self.serialize_state(scope_ptr)
        if scope.path[-1] == "Account":
            return self.serialize_account(scope_ptr)
        if scope.path[-1] == "Address":
            return self.serialize_address(scope_ptr)
        if scope.path[-1] == "Event":
            return self.serialize_event(scope_ptr)
        if scope.path[-1] == "Transfer":
            return self.serialize_transfer(scope_ptr)
        if scope.path[-1] == "EthTransaction":
            return self.serialize_eth_transaction(scope_ptr)
        if scope.path[-1] == "Stack":
            return self.serialize_stack(scope_ptr)
        raise ValueError(f"Unknown scope {scope}")

    def serialize(self, cairo_type, i=1):
        if isinstance(cairo_type, TypePointer):
            return self.serialize_scope(
                cairo_type.pointee.scope,
                self.memory.get(self.runner.vm.run_context.ap - i),
            )
        if isinstance(cairo_type, TypeTuple):
            return [
                self.serialize(m.typ, len(cairo_type.members) - i)
                for i, m in enumerate(cairo_type.members)
            ]
        if isinstance(cairo_type, TypeFelt):
            return self.memory.get(self.runner.vm.run_context.ap - i)
        raise ValueError(f"Unknown type {cairo_type}")
