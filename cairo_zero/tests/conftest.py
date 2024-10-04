# ruff: noqa: F403
import sys
from pathlib import Path

# Import everything from the root conftest.py
from tests.conftest import *
from tests.fixtures import *
from tests.utils import *

# Add the project root to the Python path
project_root = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(project_root))
