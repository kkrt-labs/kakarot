// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

// Local dependencies
from kakarot.model import model
from kakarot.stack import Stack
from tests.units.kakarot.library import setup, prepare, Kakarot
from tests.model import EVMTestCase
from tests.utils import test_utils

// @title Basic EVM unit tests.
// @author @abdelhamidbakhta

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return setup();
}

@external
func test_basic_add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/001.json'
    );
    %{
        import time
        __banner__ = '''
          _  __     _                   _                                         
         | |/ /__ _| | ____ _ _ __ ___ | |_                                       
         | ' // _` | |/ / _` | '__/ _ \| __|                                      
         | . \ (_| |   < (_| | | | (_) | |_                                       
         |_|\_\__,_|_|\_\__,_|_|  \___/ \__|                                      
        '''
        __banner_2__ = '''
          ______  __     _______     ____  __ 
        |__  / |/ /    | ____\ \   / /  \/  |
           / /| ' /_____|  _|  \ \ / /| |\/| |
          / /_| . \_____| |___  \ V / | |  | |
         /____|_|\_\    |_____|  \_/  |_|  |_|                              
        '''
        print(__banner__)
        print(__banner_2__)
    %}

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, 365);

    return ();
}
