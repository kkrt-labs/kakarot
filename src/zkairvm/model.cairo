// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.bool import TRUE, FALSE

// Internal dependencies
from utils.utils import Helpers

struct ExecutionContext {
    code: felt*,
    code_len: felt,
    calldata: felt*,
    pc: felt*,
    stopped: felt*,
    return_data: felt*,
    verbose: felt,  // for debug purpose
}

struct ExecutionStep {
    pc: felt,
    opcode: felt,
    gas: felt,
}

namespace ExecutionContextModel {
    func get_pc(ctx: ExecutionContext) -> (pc: felt) {
        alloc_locals;
        let (pc) = Helpers.get_last(ctx.pc);
        return (pc=pc);
    }

    func set_pc(ctx: ExecutionContext, pc: felt) {
        let (pc_len) = Helpers.get_len(ctx.pc);
        assert [ctx.pc + pc_len] = pc;
        return ();
    }

    func inc_pc(ctx: ExecutionContext, inc_value: felt) {
        let (pc) = get_pc(ctx);
        set_pc(ctx, pc + inc_value);
        return ();
    }

    func is_stopped(ctx: ExecutionContext) -> (stopped: felt) {
        let (stopped) = Helpers.has_entries(ctx.stopped);
        return (stopped=stopped);
    }

    func stop(ctx: ExecutionContext) {
        assert [ctx.stopped] = TRUE;
        return ();
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
                "return_data": f"{return_data}",
            }
            post_debug(json)
        %}
        return ();
    }
}
