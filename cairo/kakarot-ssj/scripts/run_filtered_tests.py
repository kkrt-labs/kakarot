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

        for file in PROJECT_FILES:
            if (src_file := src_path / file).exists():
                shutil.copy2(src_file, temp_path / file)

        if (src_crates := src_path / "crates").exists():
            shutil.copytree(src_crates, temp_path / "crates", symlinks=True)

        yield temp_path


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
    with subprocess.Popen(
        command, shell=True, stdout=slave, stderr=slave, close_fds=True, cwd=cwd
    ) as process:
        os.close(slave)
        stream_output(master)
        return_code = process.wait()

    if return_code != 0:
        print(f"Error: Scarb command failed with return code {return_code}")
        sys.exit(return_code)


def run_filtered_tests(package, filter_name):
    project_root = Path(__file__).parent.parent

    with temporary_project_copy(project_root) as temp_project_dir:
        filter_tests(temp_project_dir / "crates", filter_name)
        run_scarb_command(f"scarb test -p {package} {filter_name}", temp_project_dir)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python run_filtered_tests.py <package> <filter_name>")
        sys.exit(1)

    run_filtered_tests(sys.argv[1], sys.argv[2])
