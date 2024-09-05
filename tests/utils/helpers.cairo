// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict import dict_write
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.memset import memset
from starkware.cairo.common.uint256 import Uint256, uint256_eq, assert_uint256_eq
from starkware.cairo.common.dict_access import DictAccess

from backend.starknet import Starknet
from kakarot.account import Account
from kakarot.constants import Constants
from kakarot.evm import EVM
from kakarot.library import Kakarot
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.maths import unsigned_div_rem
from utils.utils import Helpers

namespace TestHelpers {
    func init_evm_at_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytecode_len: felt,
        bytecode: felt*,
        starknet_contract_address: felt,
        evm_contract_address: felt,
        calldata_len: felt,
        calldata: felt*,
    ) -> model.EVM* {
        alloc_locals;
        let (chain_id) = Kakarot.eth_chain_id();
        let env = Starknet.get_env(0, 0, chain_id);
        tempvar address = new model.Address(
            starknet=starknet_contract_address, evm=evm_contract_address
        );
        let (valid_jumpdests_start, valid_jumpdests) = Helpers.initialize_jumpdests(
            bytecode_len=bytecode_len, bytecode=bytecode
        );
        tempvar zero = new Uint256(0, 0);
        local message: model.Message* = new model.Message(
            bytecode=bytecode,
            bytecode_len=bytecode_len,
            valid_jumpdests_start=valid_jumpdests_start,
            valid_jumpdests=valid_jumpdests,
            calldata=calldata,
            calldata_len=calldata_len,
            value=zero,
            caller=env.origin,
            parent=cast(0, model.Parent*),
            address=address,
            code_address=address,
            read_only=FALSE,
            is_create=FALSE,
            depth=0,
            env=env,
            cairo_precompile_called=FALSE,
        );
        let evm: model.EVM* = EVM.init(message, 1000000);
        return evm;
    }

    func init_evm{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> model.EVM* {
        let (bytecode) = alloc();
        let (calldata) = alloc();
        return init_evm_at_address(0, bytecode, 0, 0, 0, calldata);
    }

    func init_evm_with_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytecode_len: felt, bytecode: felt*
    ) -> model.EVM* {
        let (calldata) = alloc();
        return init_evm_at_address(bytecode_len, bytecode, 0, 0, 0, calldata);
    }

    func init_evm_with_calldata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytecode_len: felt, bytecode: felt*, calldata_len: felt, calldata: felt*
    ) -> model.EVM* {
        return init_evm_at_address(bytecode_len, bytecode, 0, 0, calldata_len, calldata);
    }

    func init_stack_with_values(stack_len: felt, stack: Uint256*) -> model.Stack* {
        let stack_ = Stack.init();

        tempvar stack_ = stack_;
        tempvar stack_len = stack_len;
        tempvar stack = stack;

        jmp cond;

        loop:
        let stack_ = cast([ap - 3], model.Stack*);
        let stack_len = [ap - 2];
        let stack = cast([ap - 1], Uint256*);

        Stack.push{stack=stack_}(stack + (stack_len - 1) * Uint256.SIZE);

        tempvar stack_len = stack_len - 1;
        tempvar stack = stack;

        static_assert stack_ == [ap - 3];
        static_assert stack_len == [ap - 2];
        static_assert stack == [ap - 1];

        cond:
        let stack_len = [ap - 2];
        jmp loop if stack_len != 0;

        let stack_ = cast([ap - 3], model.Stack*);

        return stack_;
    }

    func init_memory_with_values{range_check_ptr}(
        serialized_memory_len: felt, serialized_memory: felt*
    ) -> model.Memory* {
        alloc_locals;
        let memory = Memory.init();
        let (words_len, _) = unsigned_div_rem(serialized_memory_len + 31, 32);
        tempvar memory = new model.Memory(memory.word_dict_start, memory.word_dict, words_len);
        with memory {
            Memory.store_n(serialized_memory_len, serialized_memory, 0);
        }
        return memory;
    }

    func init_jumpdests_with_values(jumpdests_len: felt, jumpdests: felt*) -> (
        DictAccess*, DictAccess*
    ) {
        alloc_locals;
        let (local valid_jumpdests_start) = default_dict_new(0);
        let valid_jumpdests = valid_jumpdests_start;

        tempvar valid_jumpdests = valid_jumpdests;
        tempvar jumpdests_len = jumpdests_len;
        tempvar jumpdests = jumpdests;

        jmp cond;

        loop:
        let valid_jumpdests = cast([ap - 3], DictAccess*);
        let jumpdests_len = [ap - 2];
        let jumpdests = cast([ap - 1], felt*);

        dict_write{dict_ptr=valid_jumpdests}(jumpdests[jumpdests_len - 1], 1);

        tempvar jumpdests_len = jumpdests_len - 1;
        tempvar jumpdests = jumpdests;

        static_assert valid_jumpdests == [ap - 3];
        static_assert jumpdests_len == [ap - 2];
        static_assert jumpdests == [ap - 1];

        cond:
        let jumpdests_len = [ap - 2];
        jmp loop if jumpdests_len != 0;

        let valid_jumpdests = cast([ap - 3], DictAccess*);
        let valid_jumpdests_start = cast([fp], DictAccess*);

        return (valid_jumpdests_start, valid_jumpdests);
    }

    func assert_array_equal(array_0_len: felt, array_0: felt*, array_1_len: felt, array_1: felt*) {
        assert array_0_len = array_1_len;
        if (array_0_len == 0) {
            return ();
        }
        assert [array_0] = [array_1];
        return assert_array_equal(array_0_len - 1, array_0 + 1, array_1_len - 1, array_1 + 1);
    }

    func assert_message_equal(evm_0: model.Message*, evm_1: model.Message*) {
        assert evm_0.value = evm_1.value;
        assert_array_equal(evm_0.bytecode_len, evm_0.bytecode, evm_1.bytecode_len, evm_1.bytecode);
        assert_array_equal(evm_0.calldata_len, evm_0.calldata, evm_1.calldata_len, evm_1.calldata);

        assert evm_0.address.starknet = evm_1.address.starknet;
        assert evm_0.gas_price = evm_1.gas_price;
        assert evm_0.address.evm = evm_1.address.evm;
        assert_execution_context_equal(evm_0.parent, evm_1.parent);
        return ();
    }

    func assert_execution_context_equal(evm_0: model.EVM*, evm_1: model.EVM*) {
        assert evm_0.message.depth = evm_1.message.depth;

        assert_message_equal(evm_0.message, evm_1.message);
        assert evm_0.program_counter = evm_1.program_counter;
        assert evm_0.stopped = evm_1.stopped;

        assert_array_equal(
            evm_0.return_data_len, evm_0.return_data, evm_1.return_data_len, evm_1.return_data
        );

        // TODO: Implement assert_dict_access_equal and finalize this helper once Stack and Memory are stabilized
        // assert evm_0.stack = evm_1.stack;
        // assert evm_0.memory = evm_1.memory;
        return ();
    }
}
