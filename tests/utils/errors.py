import re
from contextlib import contextmanager

import pytest
from web3 import Web3


@contextmanager
def evm_error(message=None):
    try:
        with pytest.raises(Exception) as e:
            yield e
        # FIXME: We should catch only Evm errors
        # FIXME: When all the other Kakarot errors are fixed (e.g. Kakarot: StateModificationError)
        # FIXME: uncomment this
        # assert e.typename == "EvmTransactionError"
        # When Web3 is connected, it's not possible to have the return_data so we skip the check
        if message is None or Web3().is_connected():
            return
        revert_reason = bytes(e.value.args[0])
        message = message.encode() if isinstance(message, str) else message
        assert (
            message.hex() in revert_reason.hex()
        ), f"Expected {message}, got {revert_reason}"
    finally:
        pass


@contextmanager
def cairo_error(message=None):
    try:
        with pytest.raises(Exception) as e:
            yield e
        if message is None:
            return
        error = re.search(r"Error message: (.*)", e.value.__str__())[1]  # type: ignore
        assert message == error, f"Expected {message}, got {error}"
    finally:
        pass
