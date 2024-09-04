import shutil
from pathlib import Path

import pytest

from tests.utils.coverage import report_runs
from tests.utils.reporting import dump_coverage


@pytest.fixture(scope="session", autouse=True)
async def coverage(worker_id):

    output_dir = Path("coverage")
    shutil.rmtree(output_dir, ignore_errors=True)

    yield

    output_dir.mkdir(exist_ok=True, parents=True)
    files = report_runs(excluded_file={"site-packages", "tests"})

    if worker_id == "master":
        dump_coverage(output_dir, files)
    else:
        dump_coverage(output_dir / worker_id, files)
