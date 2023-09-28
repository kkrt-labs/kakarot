def is_account_eoa(state: dict) -> bool:
    return state.get("code") in [None, "0x"] and not state.get("storage")
