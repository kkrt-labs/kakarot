import json
import os
import subprocess


def compile_vyper_contract(filename, output_dir):
    # Prepare commands for compiling the contract to bytecode and ABI
    bytecode_command = ["vyper", filename]
    abi_command = ["vyper", "-f", "abi", filename]

    # Execute the compilation commands
    bytecode_result = subprocess.run(bytecode_command, capture_output=True, text=True)
    abi_result = subprocess.run(abi_command, capture_output=True, text=True)

    # Check if both compilations were successful
    if bytecode_result.returncode == 0 and abi_result.returncode == 0:
        print(f"Compilation successful for {filename}, writing artifacts.")

        # Parse the ABI JSON string
        abi_data = json.loads(abi_result.stdout)

        # Create a dictionary with both bytecode and ABI
        data = {"bytecode": bytecode_result.stdout.strip(), "abi": abi_data}

        # Construct the output JSON filename based on the contract's filename
        basename = os.path.basename(filename)
        json_filename = os.path.splitext(basename)[0] + ".json"

        # Write the data to a JSON file in the specified output directory
        with open(os.path.join(output_dir, json_filename), "w") as file:
            json.dump(data, file, indent=4)
    else:
        print(f"Error during compilation of {filename}:")
        if bytecode_result.returncode != 0:
            print(bytecode_result.stderr)
        if abi_result.returncode != 0:
            print(abi_result.stderr)


def compile_all_contracts(source_dir, build_dir):
    # Ensure the build directory exists
    os.makedirs(build_dir, exist_ok=True)

    # Compile each .vy file in the source directory
    for item in os.listdir(source_dir):
        if item.endswith(".vy"):
            compile_vyper_contract(os.path.join(source_dir, item), build_dir)


if __name__ == "__main__":
    source_directory = (
        "vyper_contracts/src"  # The directory where vyper contracts are located
    )
    build_directory = (
        "vyper_contracts/build"  # The directory where compiled files will be saved
    )

    # Compile all contracts in the source directory
    compile_all_contracts(source_directory, build_directory)
