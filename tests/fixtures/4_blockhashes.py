import json
from pathlib import Path
from typing import Dict, Union

import pytest_asyncio


@pytest_asyncio.fixture(scope="session")
async def blockhashes() -> Dict[str, Union[Dict[str, int], int]]:
    with open(Path("sequencer") / "blockhashes.json") as file:
        blockhashes = json.load(file)
    return blockhashes
