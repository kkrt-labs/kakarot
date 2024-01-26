def is_account_eoa(account: dict) -> bool:
    return account.get("code") in [None, "0x"] and not account.get("storage")
