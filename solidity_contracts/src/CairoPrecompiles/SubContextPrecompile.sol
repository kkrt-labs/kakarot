// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {WhitelistedCallCairoPrecompileTest} from "./WhitelistedCallCairoPrecompileTest.sol";

contract SubContextPrecompile {
    RevertingSubContext immutable revertingSubContext;

    constructor(address _cairo_counter_caller) {
        revertingSubContext = new RevertingSubContext(_cairo_counter_caller);
    }

    function exploitLowLevelCall() public {
        (bool success,) = address(revertingSubContext).call(abi.encodeWithSignature("reverting()"));
        require(success == false);
    }

    function exploitChildContext() public {
        revertingSubContext.reverting();
    }
}

contract RevertingSubContext {
    WhitelistedCallCairoPrecompileTest immutable cairo_counter_caller;
    uint256 dummyCounter;

    constructor(address _cairo_counter_caller) {
        cairo_counter_caller = WhitelistedCallCairoPrecompileTest(_cairo_counter_caller);
    }

    function reverting() public {
        dummyCounter = 1;
        cairo_counter_caller.incrementCairoCounter();
        // force a revert after a call to a cairo precompile in a subcontext
        require(false);
    }
}
