import re
from contextlib import contextmanager

import pytest


@contextmanager
def kakarot_error(message):
    try:
        with pytest.raises(Exception) as e:
            yield e
        error = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        if re.match("Kakarot: Reverted with reason: ", error):
            error = re.search(r"Kakarot: Reverted with reason: (.*)", error)[1]  # type: ignore
            error_hex = f"{int(error):x}"
            error_hex = "0" + error_hex if len(error_hex) % 2 == 1 else error_hex
            assert message == bytes.fromhex(error_hex).decode()
        else:
            assert message == error
    finally:
        pass
