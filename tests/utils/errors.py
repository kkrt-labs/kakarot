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
            revert_reason = re.search(r"Kakarot: Reverted with reason: (.*)", error)[1]  # type: ignore
            try:
                revert_reason = int(revert_reason)
                if isinstance(message, int):
                    assert (
                        message == revert_reason
                    ), f"Expected {message}, got {revert_reason}"
                    return
                revert_reason = bytes(
                    [b for b in bytes.fromhex(f"{revert_reason:x}") if b != 0]
                )
                if isinstance(message, bytes):
                    assert (
                        message == revert_reason
                    ), f"Expected {message}, got {revert_reason}"
                    return
                if isinstance(message, str):
                    expected_short_string = wrap(message, 32)[-1].strip()
                    revert_reason_short_string = revert_reason.decode().strip()
                    assert (
                        expected_short_string == revert_reason_short_string
                    ), f"Expected {expected_short_string}, got {revert_reason_short_string}"
                    return
            except:
                assert (
                    message == revert_reason
                ), f"Expected {message}, got {revert_reason}"
        else:
            assert message == error, f"Expected {message}, got {error}"
    finally:
        pass
