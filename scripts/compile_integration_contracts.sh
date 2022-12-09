set -eu

# Store the result of the `find` command in the `solidity_files` variable.
solidity_files=$(find $PWD/tests/integration -name "*.sol")

# Iterate over each file in the `solidity_files` list.
for file in ${solidity_files}; do
    # Extract the directory and file name from the file path.
    dirname=$(dirname $file)
    basename=$(basename $file)

    # Run the `solc` compiler on the file.
    docker run -v ${dirname}:/sources ethereum/solc:stable -o /sources/build --abi --bin --overwrite --opcodes /sources/${basename} /sources/${basename}
done
