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
        let syscall_ptr = cast([fp - 8], felt*);
        let pedersen_ptr = cast([fp - 7], HashBuiltin*);
        let range_check_ptr = [fp - 6];
        let stack = cast([fp - 4], model.Stack*);
        let evm = cast([fp - 3], model.EVM*);
        let (evm, result) = Internals.blockhash(evm);
        jmp end;

        coinbase:
        tempvar syscall_ptr = cast([fp - 8], felt*);
        tempvar pedersen_ptr = cast([fp - 7], HashBuiltin*);
        tempvar range_check_ptr = [fp - 6];
        tempvar stack = cast([fp - 4], model.Stack*);
        tempvar evm = cast([fp - 3], model.EVM*);
        tempvar result = Uint256(
            0xacdffe0cf08e20ed8ba10ea97a487004, 0x388ca486b82e20cc81965d056b4cdca
        );
        jmp end;

        timestamp:
        let syscall_ptr = cast([fp - 8], felt*);
        let (block_timestamp) = get_block_timestamp();
        tempvar syscall_ptr = cast([ap - 2], felt*);
        tempvar pedersen_ptr = cast([fp - 7], HashBuiltin*);
        tempvar range_check_ptr = [fp - 6];
        tempvar stack = cast([fp - 4], model.Stack*);
        tempvar evm = cast([fp - 3], model.EVM*);
        tempvar result = Uint256(block_timestamp, 0);
        jmp end;

        number:
        let syscall_ptr = cast([fp - 8], felt*);
        let (block_number) = get_block_number();
        tempvar syscall_ptr = cast([ap - 2], felt*);
        tempvar pedersen_ptr = cast([fp - 7], HashBuiltin*);
        tempvar range_check_ptr = [fp - 6];
        tempvar stack = cast([fp - 4], model.Stack*);
        tempvar evm = cast([fp - 3], model.EVM*);
        tempvar result = Uint256(block_number, 0);
        jmp end;

        prevrandao:
        tempvar syscall_ptr = cast([fp - 8], felt*);
        tempvar pedersen_ptr = cast([fp - 7], HashBuiltin*);
        tempvar range_check_ptr = [fp - 6];
        tempvar stack = cast([fp - 4], model.Stack*);
        tempvar evm = cast([fp - 3], model.EVM*);
        tempvar result = Uint256(0, 0);
        jmp end;

        gaslimit:
        tempvar syscall_ptr = cast([fp - 8], felt*);
        tempvar pedersen_ptr = cast([fp - 7], HashBuiltin*);
        tempvar range_check_ptr = [fp - 6];
        tempvar stack = cast([fp - 4], model.Stack*);
        tempvar evm = cast([fp - 3], model.EVM*);
        tempvar result = Uint256(Constants.BLOCK_GAS_LIMIT, 0);
        jmp end;

        chainid:
        tempvar syscall_ptr = cast([fp - 8], felt*);
        tempvar pedersen_ptr = cast([fp - 7], HashBuiltin*);
        tempvar range_check_ptr = [fp - 6];
        tempvar stack = cast([fp - 4], model.Stack*);
        tempvar evm = cast([fp - 3], model.EVM*);
        tempvar result = Uint256(Constants.CHAIN_ID, 0);
        jmp end;

        selfbalance:
        let syscall_ptr = cast([fp - 8], felt*);
        let pedersen_ptr = cast([fp - 7], HashBuiltin*);
        let range_check_ptr = [fp - 6];
        let stack = cast([fp - 4], model.Stack*);
        let evm = cast([fp - 3], model.EVM*);
        let (evm, result) = Internals.selfbalance(evm);
        jmp end;

        basefee:
        // Since Kakarot does not implement EIP1559,
        // there is no priority fee, therefore gasPrice == baseFeePerGas
        let evm = cast([fp - 3], model.EVM*);
        tempvar gas_price = evm.message.gas_price;
        tempvar syscall_ptr = cast([fp - 8], felt*);
        tempvar pedersen_ptr = cast([fp - 7], HashBuiltin*);
        tempvar range_check_ptr = [fp - 6];
        tempvar stack = cast([fp - 4], model.Stack*);
        tempvar evm = cast([fp - 3], model.EVM*);
        // TODO: since gas_price is a felt, it might panic when being cast to a Uint256.low,
        // Add check gas_price < 2 ** 128 at creation of EVM
        // `split_felt` might be too expensive for this if we know gas_price < 2 ** 128
        tempvar result = Uint256(gas_price, 0);
        jmp end;

        end:
        // Rebind unused args with fp
        let bitwise_ptr = cast([fp - 5], BitwiseBuiltin*);

        // Rebind used args with ap
        let syscall_ptr = cast([ap - 7], felt*);
        let pedersen_ptr = cast([ap - 6], HashBuiltin*);
        let range_check_ptr = [ap - 5];
        let stack = cast([ap - 4], model.Stack*);
        let evm = cast([ap - 3], model.EVM*);
        let result = Uint256([ap - 2], [ap - 1]);

        // Finalize opcode
        Stack.push_uint256(result);
        return evm;
    }
}

namespace Internals {
    func blockhash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, stack: model.Stack*
    }(evm: model.EVM*) -> (model.EVM*, Uint256) {
        let (block_number_uint256) = Stack.pop();
        let block_number = block_number_uint256.low;

        // Check if blockNumber is within bounds by checking with current block number
        // Valid range is the last 256 blocks (not including the current one)
        let (current_block_number) = get_block_number();
        let in_range = is_in_range(block_number, current_block_number - 256, current_block_number);

        // If not in range, return 0
        if (in_range == FALSE) {
            return (evm, Uint256(0, 0));
        }

        let (blockhash_registry_address_: felt) = blockhash_registry_address.read();
        let (blockhash_: felt) = IBlockhashRegistry.get_blockhash(
            contract_address=blockhash_registry_address_, block_number=[block_number_uint256]
        );
        let blockhash = Helpers.to_uint256(blockhash_);
        return (evm, [blockhash]);
    }

    func selfbalance{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, stack: model.Stack*
    }(evm: model.EVM*) -> (model.EVM*, Uint256) {
        let (state, account) = State.get_account(evm.state, evm.message.address);
        let evm = EVM.update_state(evm, state);
        return (evm, [account.balance]);
    }
}
