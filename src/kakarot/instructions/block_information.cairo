// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_in_range
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

from kakarot.constants import Constants
from kakarot.evm import EVM
from kakarot.interfaces.interfaces import IBlockhashRegistry
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.storages import blockhash_registry_address
from utils.utils import Helpers

// @title BlockInformation information opcodes.
// @notice This file contains the functions to execute for block information opcodes.
namespace BlockInformation {
    func exec_block_information{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        let opcode_number = [evm.message.bytecode + evm.program_counter];

        tempvar offset = 2 * (opcode_number - 0x40) + 1;

        jmp rel offset;
        jmp blockhash;
        jmp coinbase;
        jmp timestamp;
        jmp number;
        jmp prevrandao;
        jmp gaslimit;
        jmp chainid;
        jmp selfbalance;
        jmp basefee;

        blockhash:
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let range_check_ptr = [fp - 8];
        let stack = cast([fp - 6], model.Stack*);
        Internals.blockhash();

        // Rebind unused args with fp
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);
        return evm;

        coinbase:
        tempvar result = Uint256(
            0xacdffe0cf08e20ed8ba10ea97a487004, 0x388ca486b82e20cc81965d056b4cdca
        );
        jmp end_constant;

        timestamp:
        let syscall_ptr = cast([fp - 10], felt*);
        let (block_timestamp) = get_block_timestamp();
        tempvar result = Uint256(block_timestamp, 0);
        jmp end_syscall;

        number:
        let syscall_ptr = cast([fp - 10], felt*);
        let (block_number) = get_block_number();
        tempvar result = Uint256(block_number, 0);
        jmp end_syscall;

        prevrandao:
        tempvar result = Uint256(0, 0);
        jmp end_constant;

        gaslimit:
        tempvar result = Uint256(Constants.BLOCK_GAS_LIMIT, 0);
        jmp end_constant;

        chainid:
        tempvar result = Uint256(Constants.CHAIN_ID, 0);
        jmp end_constant;

        selfbalance:
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let range_check_ptr = [fp - 8];
        let stack = cast([fp - 6], model.Stack*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);
        Internals.selfbalance(evm);

        // Rebind unused args with fp
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        return evm;

        basefee:
        // Since Kakarot does not implement EIP1559,
        // there is no priority fee, therefore gasPrice == baseFeePerGas
        // TODO: since gas_price is a felt, it might panic when being cast to a Uint256.low,
        // Add check gas_price < 2 ** 128 at creation of EVM
        // `split_felt` might be too expensive for this if we know gas_price < 2 ** 128
        let evm = cast([fp - 3], model.EVM*);
        tempvar gas_price = evm.message.gas_price;
        tempvar result = Uint256(gas_price, 0);
        jmp end_constant;

        end_constant:
        // Rebind unused args with fp
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let range_check_ptr = [fp - 8];
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let stack = cast([fp - 6], model.Stack*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);

        // Rebind used args with ap
        let result = Uint256([ap - 2], [ap - 1]);

        Stack.push_uint256(result);
        return evm;

        end_syscall:
        // Rebind unused args with fp
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let range_check_ptr = [fp - 8];
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let stack = cast([fp - 6], model.Stack*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);

        // Rebind used args with ap
        let syscall_ptr = cast([ap - 3], felt*);
        let result = Uint256([ap - 2], [ap - 1]);

        Stack.push_uint256(result);
        return evm;
    }
}

namespace Internals {
    func blockhash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, stack: model.Stack*
    }() {
        let (block_number_uint256) = Stack.pop();
        let block_number = block_number_uint256.low;

        // Check if blockNumber is within bounds by checking with current block number
        // Valid range is the last 256 blocks (not including the current one)
        let (current_block_number) = get_block_number();
        let in_range = is_in_range(block_number, current_block_number - 256, current_block_number);

        // If not in range, return 0
        if (in_range == FALSE) {
            Stack.push_uint256(Uint256(0, 0));
            return ();
        }

        let (blockhash_registry_address_: felt) = blockhash_registry_address.read();
        let (blockhash_: felt) = IBlockhashRegistry.get_blockhash(
            contract_address=blockhash_registry_address_, block_number=[block_number_uint256]
        );
        let blockhash = Helpers.to_uint256(blockhash_);
        Stack.push(blockhash);
        return ();
    }

    func selfbalance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        stack: model.Stack*,
        state: model.State*,
    }(evm: model.EVM*) {
        let account = State.get_account(evm.message.address);
        Stack.push(account.balance);
        return ();
    }
}
