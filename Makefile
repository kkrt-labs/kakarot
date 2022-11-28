.PHONY: build test coverage
solidity_folder = $(shell pwd)/tests/solidity_files
solidity_files  = $(shell ls ${solidity_folder} | grep .sol)

build:
	$(MAKE) clean
	poetry run starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --cairo_path ./src --abi build/kakarot_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --cairo_path ./src --abi build/contract_account_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --output build/externally_owned_account.json --cairo_path ./src --abi build/externally_owned_account_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/registry/account_registry.cairo --output build/account_registry.json --cairo_path ./src --abi build/account_registry_abi.json

build-mac:
	$(MAKE) clean
	starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --cairo_path ./src --abi build/kakarot_abi.json
	starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --cairo_path ./src --abi build/contract_account_abi.json
	starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --output build/externally_owned_account.json --cairo_path ./src --abi build/externally_owned_account_abi.json
	starknet-compile ./src/kakarot/accounts/registry/account_registry.cairo --output build/account_registry.json --cairo_path ./src --abi build/account_registry_abi.json

setup:
	poetry install --no-root

test: build-sol
	poetry run pytest tests --log-cli-level=INFO -n logical

test-no-log: build-sol
	poetry run pytest tests -n logical

test-integration: build-sol
	poetry run pytest tests/integrations --log-cli-level=INFO -n logical

test-units: build-sol
	poetry run pytest tests/units --log-cli-level=INFO

run-test-log: build-sol
	poetry run pytest -k $(test) --log-cli-level=INFO -vvv
	
run-test: build-sol
	poetry run pytest -k $(test)

run-test-mark-log: build-sol
	poetry run pytest -m $(mark) --log-cli-level=INFO -vvv

run-test-mark: build-sol
	poetry run pytest -m $(mark)

format:
	poetry run cairo-format src/**/*.cairo -i
	poetry run black tests/.
	poetry run isort tests/.

format-check:
	poetry run cairo-format src/**/*.cairo -c
	poetry run black tests/. --check
	poetry run isort tests/. --check

clean:
	rm -rf build
	mkdir build

lint:
	amarna ./src/kakarot -o lint.sarif -rules unused-imports,dead-store,unknown-decorator,unused-arguments

format-mac:
	cairo-format src/**/*.cairo -i
	black tests/.
	isort tests/.

build-sol:
	for file in ${solidity_files} ; do \
		docker run -v ${solidity_folder}:/sources ethereum/solc:stable -o /sources/output --abi --bin --overwrite --opcodes /sources/$$file /sources/$$file; \
	done

check-resources:
	poetry run python scripts/check_resources.py
