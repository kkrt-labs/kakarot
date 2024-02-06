from functools import cache

from eth_utils.address import to_checksum_address
from starkware.cairo.lang.compiler.ast.cairo_types import (
    TypeFelt,
    TypePointer,
    TypeStruct,
    TypeTuple,
)
from starkware.cairo.lang.compiler.identifier_definition import (
    AliasDefinition,
    StructDefinition,
)
from starkware.cairo.lang.compiler.identifier_manager import MissingIdentifierError


@cache
def get_identifier_definition(runner, struct_name):
    scoped_names = [
        name
        for name in runner.program.identifiers.as_dict()
        if f"model.{struct_name}" in str(name)
    ]
    if len(scoped_names) != 1:
        raise ValueError(
            f"Expected one struct named {struct_name}, found {scoped_names}"
        )
    scope = runner.program.identifiers.get_by_full_name(scoped_names[0])
    if isinstance(scope, AliasDefinition):
        scope = scope.destination
    return scope


class Serde:
    def __init__(self, runner):
        self.runner = runner
        self.memory = runner.segments.memory

    def serialize_list(self, segment_ptr, item_scope=None):
        segment_size = self.runner.segments.get_segment_size(segment_ptr.segment_index)
        output = []
        item_identifier = (
            self.runner.program.get_identifier(item_scope, StructDefinition)
            if item_scope is not None
            else None
        )
        item_size = item_identifier.size if item_identifier is not None else 1
        for i in range(0, segment_size, item_size):
            item_ptr = self.memory.get(segment_ptr + i)
            if item_ptr is None:
                break
            item = (
                self.serialize_scope(item_identifier.full_name, item_ptr)
                if item_identifier is not None
                else item_ptr
            )
            output.append(item)
        return output

    def serialize_dict(self, dict_ptr, value_scope=None):
        dict_size = self.runner.segments.get_segment_size(dict_ptr.segment_index)
        output = {}
        value_scope = (
            self.runner.program.get_identifier(value_scope, StructDefinition).full_name
            if value_scope is not None
            else None
        )
        for dict_index in range(0, dict_size, 3):
            key = self.memory.get(dict_ptr + dict_index)
            value_ptr = self.memory.get(dict_ptr + dict_index + 2)
            if value_scope is None:
                output[key] = value_ptr
            else:
                output[key] = (
                    self.serialize_scope(value_scope, value_ptr)
                    if value_ptr != 0
                    else ""
                )
        return output

    def serialize_struct(self, name, ptr):
        members = self.runner.program.get_identifier(name, StructDefinition).members
        return {
            name: self._serialize(member.cairo_type, ptr + member.offset)
            for name, member in members.items()
        }

    def serialize_address(self, ptr):
        raw = self.serialize_struct("model.Address", ptr)
        return {
            "starknet": f'0x{raw["starknet"]:064x}',
            "evm": to_checksum_address(f'{raw["evm"]:040x}'),
        }

    def serialize_uint256(self, ptr):
        raw = self.serialize_struct("Uint256", ptr)
        return hex(raw["low"] + raw["high"] * 2**128)

    def serialize_account(self, ptr):
        raw = self.serialize_struct("model.Account", ptr)
        return {
            "address": self.serialize_address(raw["address"]),
            "code": self.serialize_list(raw["code"]),
            "storage": self.serialize_dict(raw["storage"], "Uint256"),
            "nonce": raw["nonce"],
            "balance": self.serialize_uint256(raw["balance"]),
            "selfdestruct": raw["selfdestruct"],
        }

    def serialize_event(self, ptr):
        raw = self.serialize_struct("model.Event", ptr)
        return {
            "topics": self.serialize_list(raw["topics"]),
            "data": self.serialize_list(raw["data"]),
        }

    def serialize_transfer(self, ptr):
        raw = self.serialize_struct("model.Transfer", ptr)
        return {
            "sender": self.serialize_address(raw["sender"]),
            "recipient": self.serialize_address(raw["recipient"]),
            "amount": self.serialize_uint256(raw["amount"]),
        }

    def serialize_state(self, ptr):
        raw = self.serialize_struct("model.State", ptr)
        return {
            "accounts": self.serialize_dict(raw["accounts"], "model.Account"),
            "events": self.serialize_list(raw["events"], "model.Event"),
            "transfers": self.serialize_list(raw["transfers"], "model.Transfer"),
        }

    def serialize_eth_transaction(self, ptr):
        raw = self.serialize_struct("model.EthTransaction", ptr)
        return {
            "signer_nonce": raw["signer_nonce"],
            "gas_limit": raw["gas_limit"],
            "max_priority_fee_per_gas": raw["max_priority_fee_per_gas"],
            "max_fee_per_gas": raw["max_fee_per_gas"],
            "destination": (
                to_checksum_address(f'0x{raw["destination"]["value"]:040x}')
                if raw["destination"]["is_some"] == 1
                else None
            ),
            "amount": raw["amount"],
            "payload": ("0x" + bytes(raw["payload"][: raw["payload_len"]]).hex()),
            "access_list": (
                raw["access_list"][: raw["access_list_len"]]
                if raw["access_list"] is not None
                else []
            ),
            "chain_id": raw["chain_id"],
        }

    def serialize_stack(self, ptr):
        raw = self.serialize_struct("model.Stack", ptr)
        stack_dict = self.serialize_dict(raw["dict_ptr_start"], "Uint256")
        return [stack_dict[i] for i in range(raw["size"])]

    def serialize_memory(self, ptr):
        raw = self.serialize_struct("model.Memory", ptr)
        memory_dict = self.serialize_dict(raw["word_dict_start"])
        return "".join(
            [f"{memory_dict.get(i, 0):032x}" for i in range(2 * raw["words_len"])]
        )

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
        if scope.path[-1] == "Memory":
            return self.serialize_memory(scope_ptr)
        if scope.path[-1] == "Uint256":
            return self.serialize_uint256(scope_ptr)
        try:
            return self.serialize_struct(scope, scope_ptr)
        except MissingIdentifierError:
            return scope_ptr

    def _serialize(self, cairo_type, ptr):
        if isinstance(cairo_type, TypePointer):
            pointee = self.memory.get(ptr)
            # Edge case: 0 pointers are not pointer but no data
            if pointee == 0:
                return None
            # Edge case: a pointer to a felt is most probably a list
            if isinstance(cairo_type.pointee, TypeFelt):
                return self.serialize_list(pointee)
            # While a pointer to a struct is most probably a struct
            # The case Uint256 is indistinguishable as it is used for both
            # a list of uint256 and a single uint256
            return self._serialize(cairo_type.pointee, pointee)
        if isinstance(cairo_type, TypeTuple):
            return [
                self._serialize(m.typ, ptr + i)
                for i, m in enumerate(cairo_type.members)
            ]
        if isinstance(cairo_type, TypeFelt):
            return self.memory.get(ptr)
        if isinstance(cairo_type, TypeStruct):
            return self.serialize_scope(cairo_type.scope, ptr)
        raise ValueError(f"Unknown type {cairo_type}")

    def serialize(self, cairo_type):
        shift = hasattr(cairo_type, "members") and len(cairo_type.members) or 1
        return self._serialize(cairo_type, self.runner.vm.run_context.ap - shift)
