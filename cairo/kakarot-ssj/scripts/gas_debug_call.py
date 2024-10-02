import re


def process_logs(logs):
    gas_consumption = {}
    previous_gas = {}

    pattern = re.compile(
        r"Address (\d+), opcode (\w+), pc (\d+), gas left in call (\d+)"
    )

    for line in logs.split("\n"):
        match = pattern.search(line)
        if match:
            address, opcode, pc, gas_left = match.groups()
            address = int(address)
            pc = int(pc)
            gas_left = int(gas_left)

            if address not in gas_consumption:
                gas_consumption[address] = 0
                previous_gas[address] = gas_left
            else:
                gas_used = previous_gas[address] - gas_left
                gas_consumption[address] += gas_used
                previous_gas[address] = gas_left

            print(
                f"{hex(address)} - {pc} - {opcode} --> total gas used: {gas_consumption[address]}"
            )


# Example usage
logs = """
Address 1169201309864722334562947866173026415724746034380, opcode 96, pc 1, gas left in call 79978644
"""

process_logs(logs)
