// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from kakarot.model import model
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.precompiles.precompiles import Precompiles

@external
func test__is_precompile{range_check_ptr}(address: felt) -> (is_precompile: felt) {
    return (is_precompile=Precompiles.is_precompile(address));
}

@external
func test__precompiles_run{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt) -> (return_data_len: felt, return_data: felt*, reverted: felt) {
    // When
    tempvar call_context = new model.CallContext(
        bytecode=cast(0, felt*),
        bytecode_len=0,
        calldata=cast(0, felt*),
        calldata_len=0,
        value=0,
        gas_price=0,
        origin=cast(0, model.Address*),
        calling_context=cast(0, model.ExecutionContext*),
        address=cast(0, model.Address*),
        read_only=0,
        is_create=0,
    );
    let calling_context = ExecutionContext.init(call_context, Constants.TRANSACTION_GAS_LIMIT);
    let result = Precompiles.run(
        evm_address=address,
        calldata_len=0,
        calldata=cast(0, felt*),
        value=0,
        calling_context=calling_context,
        gas_left=Constants.TRANSACTION_GAS_LIMIT,
    );

    return (result.return_data_len, result.return_data, result.reverted);
}
