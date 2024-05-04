import os
import re

from starkware.starknet.public.abi import get_selector_from_name


def find_cairo_functions(directory):
    return [
        match
        for root, _, files in os.walk(directory)
        for file in files
        if file.endswith(".cairo")
        for match in re.findall(
            r"func\s+(\w+)\(", open(os.path.join(root, file)).read()
        )
    ]


def map_selectors(functions):
    return {get_selector_from_name(function): function for function in functions}


def get_function_from_selector(selectors):
    selector = int(input("Enter the hexadecimal selector: "), 16)
    print(f"Corresponding function: {selectors.get(selector, 'Not found')}")


if __name__ == "__main__":
    directory = "."
    functions = find_cairo_functions(directory)
    selectors = map_selectors(functions)
    get_function_from_selector(selectors)
