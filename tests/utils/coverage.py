"""
Copied from cairo_coverage.
"""

from collections import defaultdict
from dataclasses import dataclass
from typing import DefaultDict, List, Optional, Set

from starkware.cairo.lang.compiler.instruction import Instruction
from starkware.cairo.lang.vm.vm_core import VirtualMachine


@dataclass
class CoverageFile:
    name: str  # Filename.
    covered: Set[int]  # Tested lines.
    statements: Set[int]  # Lines with code.

    def __post_init__(self):
        if not self.statements:
            return
        self.missed = sorted(list(self.statements - self.covered))


def report_runs(excluded_file: Optional[Set[str]] = None):
    if excluded_file is None:
        excluded_file = set()
    report_dict = VmWithCoverage.covered  # Get the infos of all the covered files.
    statements = VmWithCoverage.statements  # Get the lines of codes of each files.
    files = sorted(
        [
            CoverageFile(
                statements=set(statements[file]), covered=set(coverage), name=file
            )
            for file, coverage in report_dict.items()
            if not any(excluded in file for excluded in excluded_file) and file
        ],
        key=lambda x: x.name,
    )

    reset()
    return files


def reset():
    VmWithCoverage.covered.clear()
    VmWithCoverage.statements.clear()


class VmWithCoverage(VirtualMachine):
    covered: DefaultDict[str, List[int]] = defaultdict(list)
    statements: DefaultDict[str, List[int]] = defaultdict(list)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.old_end_run = (
            super().end_run
        )  # Save the old end run function to wrap it afterwards.
        self.old_run_instruction = (
            super().run_instruction
        )  # Save the old run instruction function to wrap it afterwards.
        self.old_as_vm_exception = (
            super().as_vm_exception
        )  # Save the old vm as exception function to wrap it afterwards.
        self.touched_pcs: List[int] = []

    def run_instruction(self, instruction: Instruction):
        """Save the current pc and runs the instruction."""
        self.touched_pcs.append(self.run_context.pc.offset)
        self.old_run_instruction(instruction=instruction)

    def end_run(self):
        """In case the run doesn't fail creates report coverage."""
        self.old_end_run()
        self.cover_file()

    def as_vm_exception(
        self,
        exc,
        with_traceback: bool = True,
        notes: Optional[List[str]] = None,
        hint_index: Optional[int] = None,
    ):
        """In case the run fails creates report coverage."""
        self.cover_file()
        return self.old_as_vm_exception(exc, with_traceback, notes, hint_index)

    def pc_to_line(
        self,
        pc,
        statements: DefaultDict[str, list],
        report_dict: DefaultDict[str, List[int]],
    ) -> None:
        """Convert the touched pcs to the line numbers of the original file and saves them."""
        should_update_report = (
            pc in self.touched_pcs
        )  # If the pc is not touched by the test don't report it.
        instruct = self.program.debug_info.instruction_locations[
            pc
        ].inst  # First instruction in the debug info.
        file = instruct.input_file.filename  # Current analyzed file.
        while True:
            if "autogen" not in file:  # If file is auto generated discard it.
                lines = list(
                    range(
                        instruct.start_line,
                        instruct.end_line + 1,
                    )
                )  # Get the lines touched.
                if should_update_report:
                    report_dict[file].extend(lines)
                statements[file].extend(lines)
            if (
                instruct.parent_location is not None
            ):  # Continue until we have last parent location.
                instruct = instruct.parent_location[0]
                file = instruct.input_file.filename
            else:
                return

    def cover_file(self):
        """Add the coverage report in the report dict and all the lines of code."""
        if self.program.debug_info is not None:
            report_dict = self.__class__.covered
            statements = self.__class__.statements
            for pc in set(self.program.debug_info.instruction_locations.keys()):
                self.pc_to_line(pc=pc, report_dict=report_dict, statements=statements)
