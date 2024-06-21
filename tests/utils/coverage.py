"""
Copied from cairo_coverage.
"""

from collections import defaultdict
from dataclasses import dataclass
from os import get_terminal_size
from textwrap import wrap
from typing import Any, DefaultDict, Dict, List, Optional, Set

from starkware.cairo.lang.compiler.instruction import Instruction
from starkware.cairo.lang.compiler.program import ProgramBase
from starkware.cairo.lang.vm.builtin_runner import BuiltinRunner
from starkware.cairo.lang.vm.relocatable import MaybeRelocatable
from starkware.cairo.lang.vm.vm_core import RunContext, VirtualMachine


class Headers:
    """Headers for the report table."""

    FILE: str = "File "
    FILE_INDEX: int = 0

    COVERED: str = "Covered(%) "
    COVERED_INDEX: int = 1

    MISSED: str = "Missed(%) "
    MISSED_INDEX: int = 2

    LINES_MISSED: str = "Lines missed"
    LINE_MISSED_INDEX: int = 3


class Colors:
    """Colors to indicate if the coverage is good or not."""

    FAIL = "\033[91m"
    GREEN = "\033[92m"
    WARNING = "\033[93m"
    END = "\033[0m"


@dataclass
class CoverageFile:
    name: str  # Filename.
    covered: Set[int]  # Tested lines.
    statements: Set[int]  # Lines with code.
    precision: int = 1  # Decimals for %.

    @staticmethod
    def col_sizes(sizes=None):
        """To share the column sizes between all the instances."""
        return sizes if sizes is not None else []

    def __post_init__(self):
        if not self.statements:
            return
        self.nb_statements = len(
            self.statements
        )  # Nb of lines with code in the cairo file.
        self.nb_covered = len(self.covered)  # Nb of lines tested.
        self.missed = sorted(list(self.statements - self.covered))  # Lines not tested.
        self.nb_missed = len(self.missed)  # Nb of lines not tested.
        self.pct_covered = (
            100 * self.nb_covered / self.nb_statements
        )  # % of lines tested.
        self.pct_missed = (
            100 * self.nb_missed / self.nb_statements
        )  # % of lines not tested.

    def __str__(self):
        sizes = self.__class__.col_sizes()  # Get columns size.
        name_len = len(self.name)
        if (
            name_len > sizes[Headers.FILE_INDEX]
        ):  # If the filename is longer than the col len we crop it.
            cropped_name = self.name[
                5 + name_len - sizes[Headers.FILE_INDEX] :
            ]  # Crops the filename to the filename col size and leave room for [...] prefix.
            # Formats the string to be left aligned and to file the col size length.
            name = f"{'[...]' + cropped_name:<{sizes[Headers.FILE_INDEX]}}"
        else:
            # Pads the filename to the column length.
            name = f"{self.name:<{sizes[Headers.FILE_INDEX]}}"
        # % covered centered with right decimals.
        pct_covered = (
            f"{self.pct_covered:^{sizes[Headers.COVERED_INDEX]}.{self.precision}f}"
        )
        # % missed centered with right decimals.
        pct_missed = (
            f"{self.pct_missed:^{sizes[Headers.MISSED_INDEX]}.{self.precision}f}"
        )
        prefix = " " * (
            len(name) + len(pct_covered) + len(pct_missed) + 4
        )  # Offset of the missed lines column.
        if len(str(self.missed)) > sizes[Headers.LINE_MISSED_INDEX]:
            wrapped_missed = wrap(
                str(self.missed), sizes[Headers.LINE_MISSED_INDEX]
            )  # Wrap the missed lines list if too big.
            wrapped_missed[1:] = [
                f"{prefix}{val}" for val in wrapped_missed[1:]
            ]  # Prefix the wrapped missed lines.
            missed: str = "\n".join(wrapped_missed)  # Convert it to multiline string.
        else:
            missed = str(self.missed)
        if 0 <= self.pct_covered < 50:  # If coverage is not enough writes in red.
            color = Colors.FAIL
        elif 50 <= self.pct_covered < 80:  # If coverage is mid enough writes in yellow.
            color = Colors.WARNING
        else:  # If coverage is good write in green.
            color = Colors.GREEN
        # Formatted file line report.
        return f"{color}{name} {pct_covered} {pct_missed} {missed}{Colors.END}"


def print_sum(covered_files: List[CoverageFile]):
    """Print the coverage summary of the project."""
    try:
        term_size = get_terminal_size()
        max_name = max([len(file.name) for file in covered_files]) + 2  # Longest name.
        max_missed_lines = max(
            [len(str(file.missed)) for file in covered_files]
        )  # Length of the longest missed lines list.
        sizes = (
            CoverageFile.col_sizes()
        )  # Init the sizes list with our static method so it's available everywhere.
        sizes.extend(
            [max_name, len(Headers.COVERED), len(Headers.MISSED), max_missed_lines]
        )  # Fill the sizes.

        while (
            sum(sizes) > term_size.columns
        ):  # While the length of all the cols is > the terminal size, reduce the biggest col.
            idx = sizes.index(max(sizes))
            sizes[idx] = int(0.75 * sizes[idx])

        headers = (
            f"\n{Headers.FILE:{sizes[Headers.FILE_INDEX] + 1}}"
            f"{Headers.COVERED:{sizes[Headers.COVERED_INDEX] + 1}}"
            f"{Headers.MISSED:{sizes[Headers.MISSED_INDEX] + 1}}"
            f"{Headers.LINES_MISSED:{sizes[Headers.LINE_MISSED_INDEX] + 1}}\n"
        )  # Prepare the coverage table headers.
        underline = "-" * term_size.columns  # To separate the header from the values.
        print(headers + underline)
        for file in covered_files:  # Prints the report of each file.
            print(file)
    except OSError:
        pass


def report_runs(
    excluded_file: Optional[Set[str]] = None,
    print_summary: bool = True,
):
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
    )  # Sort the files by filename.

    if not len(files):
        print("Nothing to report")
        return []
    if print_summary:
        print_sum(covered_files=files)
    reset()
    return files


def reset():
    VmWithCoverage.covered.clear()
    VmWithCoverage.statements.clear()
    CoverageFile.col_sizes().clear()


class VmWithCoverage(VirtualMachine):
    covered: DefaultDict[str, List[int]] = defaultdict(list)
    statements: DefaultDict[str, List[int]] = defaultdict(list)

    def __init__(
        self,
        program: ProgramBase,
        run_context: RunContext,
        hint_locals: Dict[str, Any],
        static_locals: Optional[Dict[str, Any]] = None,
        builtin_runners: Optional[Dict[str, BuiltinRunner]] = None,
        program_base: Optional[MaybeRelocatable] = None,
    ):
        super().__init__(
            program=program,
            run_context=run_context,
            hint_locals=hint_locals,
            static_locals=static_locals,
            builtin_runners=builtin_runners,
            program_base=program_base,
        )
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

    def cover_file(
        self,
    ):
        """Add the coverage report in the report dict and all the lines of code."""
        if self.program.debug_info is not None:
            report_dict = self.__class__.covered
            statements = self.__class__.statements
            for pc in set(self.program.debug_info.instruction_locations.keys()):
                self.pc_to_line(pc=pc, report_dict=report_dict, statements=statements)
