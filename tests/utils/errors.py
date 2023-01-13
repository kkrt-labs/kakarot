import re
from contextlib import contextmanager
from textwrap import wrap

import pytest


@contextmanager
def kakarot_error(message=None):
    try:
        with pytest.raises(Exception) as e:
            yield e
        if message is None:
            return
        error = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
        if re.match("Kakarot: Reverted with reason: ", error):
            error = re.search(r"Kakarot: Reverted with reason: (.*)", error)[1]  # type: ignore
            try:
                revert_reason_short_string = (
                    bytes([b for b in bytes.fromhex(f"{int(error):x}") if b != 0])
                    .decode()
                    .strip()
                )
                expected_short_string = wrap(message, 32)[-1].strip()
                assert expected_short_string == revert_reason_short_string
            except:
                assert message == error
        else:
            assert message == error
    finally:
        pass
