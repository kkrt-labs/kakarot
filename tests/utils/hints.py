from collections import defaultdict
from contextlib import contextmanager
from typing import Optional
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
def patch_hint(program, hint, new_hint, scope: Optional[str] = None):
    """
    Patch a Cairo hint in a program with a new hint.

    Args:
        program: The Cairo program containing the hints
        hint: The original hint code to replace
        new_hint: The new hint code to use instead
        scope: Optional scope name to restrict which hints are patched. If provided,
              only hints in scope containing this string will be patched.

    Example:
        with patch_hint(program, "old_hint", "new_hint", "initialize_jumpdests"):
            # Code that runs with the patched hint

    """
    patched_hints = {
        k: [
            (
                hint_
                if hint_.code != hint
                or (scope is not None and scope not in str(hint_.accessible_scopes[-1]))
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


@contextmanager
def insert_hint(program, location: str, hint):
    """
    Insert a hint at a given location in the program.

    The location should be file_name:line_number.

    """
    instructions = {
        index: loc
        for index, loc in program.debug_info.instruction_locations.items()
        if location in str(loc.inst)
    }
    if not instructions:
        raise ValueError(f"Location {location} not found in program.")
    pc, instruction = list(instructions.items())[0]
    hint = CairoHint(
        accessible_scopes=instruction.accessible_scopes,
        flow_tracking_data=instruction.flow_tracking_data,
        code=hint,
    )
    new_hints = program.hints.copy()
    new_hints[pc] = [*new_hints.get(pc, []), hint]
    with (
        patch.object(instruction, "hints", new=new_hints.get(pc, [])),
        patch.object(program, "hints", new=new_hints),
    ):
        yield
