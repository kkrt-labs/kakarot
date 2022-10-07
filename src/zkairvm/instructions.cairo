// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.registers import get_label_location

// Internal dependencies
from zkairvm.model import ExecutionContext

namespace EVMInstructions {
    // Define constants
    const BYTE_MAX_VALUE = 255;
    const OPCODE_MAX_VALUE = BYTE_MAX_VALUE;
    const UNKNOWN_OPCODE_VALUE = OPCODE_MAX_VALUE + 1;
    const INSTRUCTIONS_LEN = OPCODE_MAX_VALUE + 1;

    // Generates the instructions set for the EVM
    func generate_instructions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (instructions: codeoffset*) {
        alloc_locals;
        // init instructions
        let (instructions_len, instructions) = new_array_with_default_value(
            OPCODE_MAX_VALUE + 1, unknown_opcode
        );
        let (local array_test: felt*) = alloc();
        assert [array_test + 2] = cast(exec_stop, felt);
        assert [array_test + 4] = cast(exec_add, felt);

        local ex_2;
        local ex_3;
        local ex_4;

        %{
            #print(f"{memory[ids.array_test + 2]}")
            #print(f"{memory.get(ids.array_test + 3)}")
            #print(f"{memory[ids.array_test + 4]}")
            # tip to check if value has been written or not
            if memory.get(ids.array_test + 2) == None:
                ids.ex_2 = 1
            if memory.get(ids.array_test + 3) == None:
                ids.ex_3 = 1
            if memory.get(ids.array_test + 4) == None:
                ids.ex_4 = 1
        %}
        assert ex_2 = 0;
        assert ex_3 = 1;
        assert ex_4 = 0;

        let fn_2_felt = array_test[2];
        let fn_2_codeoffset = cast(fn_2_felt, codeoffset);
        let (fn_2_pc) = get_label_location(fn_2_codeoffset);

        let fn_4_felt = array_test[4];
        let fn_4_codeoffset = cast(fn_4_felt, codeoffset);
        let (fn_4_pc) = get_label_location(fn_4_codeoffset);
        let (empty_return_data: felt*) = alloc();

        let ctx: ExecutionContext = ExecutionContext(
            code=empty_return_data,
            calldata=empty_return_data,
            pc=0,
            stopped=0,
            return_data=empty_return_data,
            verbose=0,
        );
        let (args: ExecutionContext*) = alloc();
        assert [args] = ctx;
        invoke(fn_2_pc, 1, args);
        invoke(fn_4_pc, 1, args);

        // add instructions

        // add 0s: Stop and Arithmetic Operations
        add_instruction(instructions, 0, exec_stop);  // 0x00 - STOP

        return (instructions=instructions);
    }

    func new_array_with_default_value(array_len: felt, default_value: codeoffset) -> (
        array_len: felt, array: codeoffset*
    ) {
        alloc_locals;
        let (local array: codeoffset*) = alloc();
        fill_with_value(array_len, array, default_value);
        return (array_len, array);
    }

    func fill_with_value(array_len: felt, array: codeoffset*, value: codeoffset) {
        alloc_locals;
        if (array_len == 0) {
            return ();
        }
        assert [array] = value;
        fill_with_value(array_len - 1, array + 1, value);
        return ();
    }

    // Decodes the current opcode and execute associated function
    // @param instructions the instruction set
    // @param opcode the opcode value
    // @param ctx the execution context
    func decode_and_execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: codeoffset*, ctx: ExecutionContext
    ) {
        alloc_locals;

        // TODO: check if pc < 0 and revert with InvalidCodeOffset
        // TODO: check if pc > len(code) and process it as a STOP if true

        // read current opcode
        let opcode = ctx.code[ctx.pc];

        // read opcode in instruction set
        // let function_codeoffset = instructions[opcode];

        // prepare arguments
        // TODO: prepare arguments

        // execute the function
        // TODO: invoke the function
        return ();
    }
    // Adds an instruction in the passed instructions set
    // @param instructions the instruction set
    // @param opcode the opcode value
    // @param function the function to execute for the specified opcode
    func add_instruction{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: codeoffset*, opcode: felt, function: codeoffset
    ) {
        alloc_locals;
        assert [instructions + opcode] = function;
        return ();
    }

    // Unknow opcode
    func unknown_opcode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        // TODO: revert with UnknownOpcode error
        return ();
    }

    // 0x00 - STOP
    // Halts execution
    // Since: Frontier
    // Group: Stop and Arithmetic Operations
    func exec_stop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x00 - STOP") %}
        return ();
    }

    // 0x00 - ADD
    // Addition operation
    // Since: Frontier
    // Group: Stop and Arithmetic Operations
    func exec_add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x01 - ADD") %}
        return ();
    }
}
