// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256

from kakarot.errors import Errors
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State

// @title EVM related functions.
// @notice This file contains functions related to the execution context.
namespace EVM {
    // @notice Initialize the execution context.
    // @dev Initialize the execution context of a specific contract.
    // @param message The message (see model.Message) to be executed.
    // @return EVM The initialized execution context.
    func init(message: model.Message*, gas_left: felt) -> model.EVM* {
        let (return_data: felt*) = alloc();

        return new model.EVM(
            message=message,
            return_data_len=0,
            return_data=return_data,
            program_counter=0,
            stopped=FALSE,
            gas_left=gas_left,
            reverted=FALSE,
        );
    }

    // @notice Stop the current execution context.
    // @dev When the execution context is stopped, no more instructions can be executed.
    // @param self The pointer to the execution context.
    // @param return_data_len The length of the return_data.
    // @param return_data The pointer to the return_data array.
    // @param reverted A boolean indicating whether the EVM is reverted or not.
    // @return EVM The pointer to the updated execution context.
    func stop(
        self: model.EVM*, return_data_len: felt, return_data: felt*, reverted: felt
    ) -> model.EVM* {
        return new model.EVM(
            message=self.message,
            return_data_len=return_data_len,
            return_data=return_data,
            program_counter=self.program_counter,
            stopped=TRUE,
            gas_left=self.gas_left,
            reverted=reverted,
        );
    }

    // @notice Update the return data of the current execution context.
    // @param self The pointer to the execution context.
    // @param return_data_len The length of the return_data.
    // @param return_data The pointer to the return_data array.
    // @return EVM The pointer to the updated execution context.
    func update_return_data(
        self: model.EVM*, return_data_len: felt, return_data: felt*
    ) -> model.EVM* {
        return new model.EVM(
            message=self.message,
            return_data_len=return_data_len,
            return_data=return_data,
            program_counter=self.program_counter,
            stopped=self.stopped,
            gas_left=self.gas_left,
            reverted=self.reverted,
        );
    }

    // @notice Increment the program counter.
    // @dev The program counter is incremented by the given value.
    // @param self The pointer to the execution context.
    // @param inc_value The value to increment the program counter with.
    // @return EVM The pointer to the updated execution context.
    func increment_program_counter(self: model.EVM*, inc_value: felt) -> model.EVM* {
        return new model.EVM(
            message=self.message,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=self.program_counter + inc_value,
            stopped=self.stopped,
            gas_left=self.gas_left,
            reverted=self.reverted,
        );
    }

    // @notice Increment the gas used.
    // @dev The gas used is incremented by the given value.
    // @param self The pointer to the execution context.
    // @param inc_value The value to increment the gas used with.
    // @return EVM The pointer to the updated execution context.
    func charge_gas{range_check_ptr}(self: model.EVM*, inc_value: felt) -> model.EVM* {
        let out_of_gas = is_le_felt(self.gas_left + 1, inc_value);

        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas(self.gas_left, inc_value);
            return new model.EVM(
                message=self.message,
                return_data_len=revert_reason_len,
                return_data=revert_reason,
                program_counter=self.program_counter,
                stopped=TRUE,
                gas_left=0,
                reverted=TRUE,
            );
        }

        return new model.EVM(
            message=self.message,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=self.program_counter,
            stopped=self.stopped,
            gas_left=self.gas_left - inc_value,
            reverted=self.reverted,
        );
    }

    // @notice Update the array of events to emit in the case of a execution context successfully running to completion (see `EVM.finalize`).
    // @param self The pointer to the execution context.
    // @param topics_len The length of the topics
    // @param topics The topics Uint256 array
    // @param data_len The length of the data
    // @param data The data bytes array
    func push_event{state: model.State*}(
        self: model.EVM*, topics_len: felt, topics: Uint256*, data_len: felt, data: felt*
    ) {
        alloc_locals;

        // we add the operating evm_contract_address of the execution context
        // as the first key of an event
        // we track kakarot events as those emitted from the kkrt contract
        // and map it to the corresponding EVM contract via this convention
        // this looks a bit odd and may need to be reviewed
        let (local topics_with_address: felt*) = alloc();
        assert [topics_with_address] = self.message.address.evm;
        memcpy(dst=topics_with_address + 1, src=cast(topics, felt*), len=topics_len * Uint256.SIZE);
        let event = model.Event(
            topics_len=1 + topics_len * Uint256.SIZE,
            topics=topics_with_address,
            data_len=data_len,
            data=data,
        );

        State.add_event(event);

        return ();
    }

    // @notice Update the program counter.
    // @dev The program counter is updated to a given value. This is only ever called by JUMP or JUMPI
    // @param self The pointer to the execution context.
    // @param new_pc_offset The value to update the program counter by.
    // @return EVM The pointer to the updated execution context.
    func jump{range_check_ptr}(self: model.EVM*, new_pc_offset: felt) -> model.EVM* {
        let out_of_range = is_le(self.message.bytecode_len, new_pc_offset);
        if (out_of_range != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.invalidJumpDestError();
            let evm = EVM.stop(self, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        if ([self.message.bytecode + new_pc_offset] != 0x5b) {
            let (revert_reason_len, revert_reason) = Errors.jumpToNonJumpdest();
            let evm = EVM.stop(self, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        return new model.EVM(
            message=self.message,
            return_data_len=self.return_data_len,
            return_data=self.return_data,
            program_counter=new_pc_offset,
            stopped=self.stopped,
            gas_left=self.gas_left,
            reverted=self.reverted,
        );
    }
}
