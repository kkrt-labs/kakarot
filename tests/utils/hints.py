from collections import defaultdict
from contextlib import contextmanager
from unittest.mock import patch

from starkware.cairo.common.dict import DictTracker
from starkware.cairo.lang.compiler.program import CairoHint


def debug_info(program):
    def _debug_info(pc):
        print(
            program.debug_info.instruction_locations.get(
                pc.offset
            ).inst.to_string_with_content("")
        )

    return _debug_info


def new_default_dict(
    dict_manager, segments, default_value, initial_dict, temp_segment: bool = False
):
    """
    Create a new Cairo default dictionary.
    """
    base = segments.add_temp_segment() if temp_segment else segments.add()
    assert base.segment_index not in dict_manager.trackers
    dict_manager.trackers[base.segment_index] = DictTracker(
        data=defaultdict(lambda: default_value, initial_dict),
        current_ptr=base,
    )
    return base


@contextmanager
def patch_hint(program, hint, new_hint):
    patched_hints = {
        k: [
            (
                hint_
                if hint_.code != hint
                else CairoHint(
                    accessible_scopes=hint_.accessible_scopes,
                    flow_tracking_data=hint_.flow_tracking_data,
                    code=new_hint,
                )
            )
            for hint_ in v
        ]
        for k, v in program.hints.items()
    }
    if patched_hints == program.hints:
        raise ValueError(f"Hint\n\n{hint}\n\nnot found in program hints.")
    with patch.object(program, "hints", new=patched_hints):
        yield
