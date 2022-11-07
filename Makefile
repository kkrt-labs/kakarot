.PHONY: build test coverage

build:
	$(MAKE) clean
	poetry run starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --disable_hint_validation --cairo_path ./src --abi build/kakarot_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --disable_hint_validation --cairo_path ./src --abi build/contract_account_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --output build/externally_owned_account.json --disable_hint_validation --cairo_path ./src --abi build/externally_owned_account_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/registry/account_registry.cairo --output build/account_registry.json --disable_hint_validation --cairo_path ./src --abi build/account_registry_abi.json

build-mac:
	$(MAKE) clean
	starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --disable_hint_validation --cairo_path ./src --abi build/kakarot_abi.json
	starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --disable_hint_validation --cairo_path ./src --abi build/contract_account_abi.json
	starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --output build/externally_owned_account.json --disable_hint_validation --cairo_path ./src --abi build/externally_owned_account_abi.json
	starknet-compile ./src/kakarot/accounts/registry/account_registry.cairo --output build/account_registry.json --disable_hint_validation --cairo_path ./src --abi build/account_registry_abi.json


setup:
	poetry install --no-root

test:
	poetry run pytest tests -s --log-cli-level=INFO

test-no-log:
	poetry run pytest tests -s

test-integration:
	poetry run pytest tests/integrations -s --log-cli-level=INFO

test-units:
	poetry run pytest tests/units -s --log-cli-level=INFO

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

run-test-log:
	poetry run pytest tests/test_zk_evm.py::TestZkEVM -k $(test) -s --log-cli-level=INFO
	
run-test:
	poetry run pytest -s -vvv tests/test_zk_evm.py::TestZkEVM::test_execute["$(test)"]

format-mac:
	cairo-format src/**/*.cairo -i
	black tests/.
	isort tests/.
