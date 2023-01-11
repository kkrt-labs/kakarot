import re
from contextlib import contextmanager

import pytest


@contextmanager
def kakarot_error(message):
    try:
        with pytest.raises(Exception) as e:
            yield e
        error = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        assert message == bytes.fromhex(f"{int(error):x}").decode()
    finally:
        pass
