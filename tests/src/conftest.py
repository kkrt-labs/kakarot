import shutil
from pathlib import Path

import pytest

from tests.utils.coverage import report_runs
from tests.utils.reporting import dump_coverage


@pytest.fixture(scope="session", autouse=True)
async def coverage(worker_id):
    yield

    files = report_runs(excluded_file={"site-packages", "tests"})

    output_dir = Path("coverage")
    if worker_id != "master":
        output_dir = output_dir / worker_id

    output_dir.mkdir(exist_ok=True, parents=True)
    shutil.rmtree(output_dir, ignore_errors=True)
    dump_coverage(output_dir, files)
