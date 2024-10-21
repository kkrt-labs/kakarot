#!/bin/bash

cat <<EOT >>.git/hooks/pre-commit
#!/bin/sh

# Run scarb fmt to format the project.
scarb fmt

# Check if any files were modified after running scarb fmt.
changed_files=$(git diff --name-only || true)

if [ -n "${changed_files}" ]; then
    echo "The following files were reformatted and staged:"
    echo "${changed_files}"
    # Stage the changes.
    git add ${changed_files}
else
    echo "No files were reformatted."
fi

# Continue with the commit
exit 0
EOT

# Check if the current directory is a git repository
if [[ ! -d .git ]]; then
	echo "Error: This is not a git repository."
	exit 1
fi

# Make the hook executable
chmod +x .git/hooks/pre-commit

echo "pre-commit hook has been installed successfully!"
echo "pre-push hook has been installed successfully!"
