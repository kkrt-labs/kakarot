import os
import re
import sys


def filter_tests(directory, filter_string):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".cairo"):
                file_path = os.path.join(root, file)
                filter_file(file_path, filter_string)

    print(f"Filtered tests for {filter_string}")


def filter_file(file_path, filter_string):
    with open(file_path, "r") as f:
        content = f.read()

    # Regular expression to match test functions, including nested braces
    test_pattern = re.compile(
        r"#\[test\]\s*(?:#\[available_gas\([^\)]+\)\]\s*)?fn\s+(\w+)\s*\([^)]*\)\s*(\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\})",
        re.DOTALL,
    )

    def replace_func(match):
        full_match = match.group(0)
        func_name = match.group(1)

        if filter_string.lower() in func_name.lower():
            return full_match
        else:
            return ""

    new_content = test_pattern.sub(replace_func, content)

    if new_content != content:
        with open(file_path, "w") as f:
            f.write(new_content)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python filter_tests.py <filter_string>")
        sys.exit(1)

    filter_string = sys.argv[1]
    crates_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "crates"
    )
    filter_tests(crates_dir, filter_string)
