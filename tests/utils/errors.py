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
            try:
                assert message == bytes.fromhex(f"{int(error):x}").decode()
            except:
                assert message == error
        else:
            assert message == error
    finally:
        pass
