import json
from pathlib import Path
from typing import Dict, Union

import pytest_asyncio


@pytest_asyncio.fixture(scope="session")
async def blockhashes() -> Dict[str, Union[Dict[str, int], int]]:
    # For testing, we use the mock file
    with open(Path("sequencer") / "mock_blockhashes.json") as file:
        blockhashes = json.load(file)
    return blockhashes
