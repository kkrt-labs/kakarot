// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.bool import TRUE, FALSE

// Internal dependencies
from tests.utils import Helpers

struct ExecutionContext {
    code: felt*,
    calldata: felt*,
    pc: felt*,
    stopped: felt*,
    return_data: felt*,
    verbose: felt,  // for debug purpose
}

struct ExecutionStep {
}

namespace ExecutionContextModel {
    func get_pc(ctx: ExecutionContext) -> (pc: felt) {
        let (pc) = Helpers.get_last(ctx.pc);
        return (pc=pc);
    }

    func is_stopped(ctx: ExecutionContext) -> (stopped: felt) {
        let (stopped) = Helpers.has_entries(ctx.stopped);
        return (stopped=stopped);
    }

    func dump(ctx: ExecutionContext) {
        let (pc) = get_pc(ctx);
        let (stopped) = is_stopped(ctx);
        %{
            code = cairo_bytes_to_hex(ids.ctx.code)
            calldata = cairo_bytes_to_hex(ids.ctx.calldata)
            return_data = cairo_bytes_to_hex(ids.ctx.return_data)
            json = {
                "pc": f"{ids.pc}",
                "stopped": f"{ids.stopped}",
                "code": f"{code}",
                "calldata": f"{calldata}",
                "return_data": f"{return_data}",
            }
            post_debug(json)
        %}
        return ();
    }
}
