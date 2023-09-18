#!/bin/bash

# Function to check if curl request is successful
function check_katana_status() {
	local retries=10
	local delay=3

	until [[ ${retries} -eq 0 ]]; do
		if curl -s http://0.0.0.0:5050 \
			-H 'content-type: application/json' \
			--data-raw '{"method":"starknet_chainId","jsonrpc":"2.0","params":[],"id":0}' \
			--compressed >/dev/null; then
			echo "curl request succeeded for katana"
			return 0
		else
			echo "curl request failed for katana, retrying"
			sleep "${delay}"
			retries=$((retries - 1))
		fi
	done

	echo "curl request failed after retries. Exiting..."
	return 1
}

check_katana_status || exit 1

cd ../kakarot || exit
poetry run python scripts/deploy_kakarot.py

if [[ $? -eq 0 ]]; then
	echo "Command executed successfully."
	# Perform further actions
else
	echo "Command failed with an error."
	# Handle the error or exit the script
fi

echo $? >/root/.kakarot_deploy_status
