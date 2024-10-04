import os
import pty
import select
import shutil
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path

from filter_tests import filter_tests

PROJECT_FILES = ["Scarb.toml", "Scarb.lock", ".tool-versions"]


@contextmanager
def temporary_project_copy(src_dir):
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        src_path = Path(src_dir)
        temp_dir_creation_time = temp_path.stat().st_ctime

        for file in PROJECT_FILES:
            if (src_file := src_path / file).exists():
                shutil.copy2(src_file, temp_path / file)

        if (src_crates := src_path / "crates").exists():
            shutil.copytree(src_crates, temp_path / "crates", symlinks=True)

        yield temp_path

        # Copy back only newly created or modified files, excluding build/ directories and .cairo files
        for root, dirs, files in os.walk(temp_path):
            dirs[:] = [
                d for d in dirs if d != "target"
            ]  # Don't traverse into build directories
            for file in files:
                temp_file = Path(root) / file
                rel_path = temp_file.relative_to(temp_path)
                src_file = src_path / rel_path

                if (
                    not src_file.exists()
                    or temp_file.stat().st_mtime > temp_dir_creation_time
                ) and temp_file.suffix != ".cairo":
                    src_file.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(temp_file, src_file)
                    print(f"Copied new or modified file: {rel_path}")


def stream_output(fd):
    while True:
        try:
            r, _, _ = select.select([fd], [], [], 0.1)
            if r:
                data = os.read(fd, 1024)
                if not data:
                    break
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
        except OSError:
            break


def run_scarb_command(command, cwd):
    master, slave = pty.openpty()
    print(f"Running command: {command}")
    with subprocess.Popen(
        command, shell=True, stdout=slave, stderr=slave, close_fds=True, cwd=cwd
    ) as process:
        os.close(slave)
        stream_output(master)
        return_code = process.wait()

    if return_code != 0:
        print(f"Error: Scarb command failed with return code {return_code}")
        sys.exit(return_code)


def run_filtered_tests(command):
    project_root = Path(__file__).parent.parent

    with temporary_project_copy(project_root) as temp_project_dir:
        # Extract the package and filter name from the command
        cmd_parts = command.split()
        package_index = cmd_parts.index("-p") + 1
        cmd_parts[package_index]
        filter_name = cmd_parts[package_index + 1]

        filter_tests(temp_project_dir / "crates", filter_name)
        run_scarb_command(command, temp_project_dir)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python run_filtered_tests.py <full_command>")
        print("Example: python run_filtered_tests.py scarb test -p evm foo")
        print(
            "Example: python run_filtered_tests.py snforge test -p evm foo --build-profile"
        )
        sys.exit(1)

    full_command = " ".join(sys.argv[1:])
    run_filtered_tests(full_command)
