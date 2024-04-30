import os
import re

from starkware.starknet.public.abi import get_selector_from_name


def find_cairo_functions(directory):
    function_names = []

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".cairo"):
                file_path = os.path.join(root, file)
                with open(file_path, "r") as f:
                    content = f.read()
                    matches = re.findall(r"func\s+(\w+)\(", content)
                    function_names.extend(matches)

    return function_names


def map_selectors(functions):
    selectors = {}
    for function in functions:
        selector = get_selector_from_name(function)
        if selector not in selectors:
            selectors[selector] = function
    return selectors


def get_function_from_selector(selectors):
    selector = int(input("Enter the selector: "))
    if selector in selectors:
        function_name = selectors[selector]
        print(f"Function corresponding to selector {selector}: {function_name}")
    else:
        print(f"No function found for selector {selector}")


# Directory to start the search from
directory = "."

# Find all the function names in .cairo files
functions = find_cairo_functions(directory)
selectors = map_selectors(functions)


# Get the function name based on user input
get_function_from_selector(selectors)
