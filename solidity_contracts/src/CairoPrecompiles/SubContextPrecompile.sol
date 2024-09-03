// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {CairoCounterCaller} from "./CairoCounterCaller.sol";

contract SubContextPrecompile {
    RevertingSubContext immutable revertingSubContext;

    constructor(address _cairo_counter_caller) {
        revertingSubContext = new RevertingSubContext(_cairo_counter_caller);
    }

    function exploitLowLevelCall() public {
        (bool success,) = address(revertingSubContext).call(abi.encodeWithSignature("reverting()"));
    }

    function exploitChildContext() public {
        revertingSubContext.reverting();
    }
}

contract RevertingSubContext {
    CairoCounterCaller immutable cairo_counter_caller;
    uint256 dummyCounter;

    constructor(address _cairo_counter_caller) {
        cairo_counter_caller = CairoCounterCaller(_cairo_counter_caller);
    }

    function reverting() public {
        dummyCounter = 1;
        cairo_counter_caller.incrementCairoCounter();
        // force a revert after a call to a cairo precompile in a subcontext
        require(false);
    }
}
