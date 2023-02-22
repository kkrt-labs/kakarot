.PHONY: build test coverage
cairo_files = $(shell find . -type f -name "*.cairo")

build: check
	$(MAKE) clean
	poetry run starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --cairo_path ./src --abi build/kakarot_abi.json
	poetry run starknet-compile ./src/kakarot/registry/blockhash/blockhash_registry.cairo --output build/blockhash_registry.json --cairo_path ./src --abi build/blockhash_registry_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --cairo_path ./src --abi build/contract_account_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --account_contract --output build/externally_owned_account.json --cairo_path ./src --abi build/externally_owned_account_abi.json
	poetry run starknet-compile ./src/kakarot/accounts/proxy/proxy.cairo --output build/proxy_account.json --cairo_path ./src --abi build/proxy_account_abi.json


build-mac: check
	$(MAKE) clean
	starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --cairo_path ./src --abi build/kakarot_abi.json
	starknet-compile ./src/kakarot/registry/blockhash/blockhash_registry.cairo --output build/blockhash_registry.json --cairo_path ./src --abi build/blockhash_registry_abi.json
	starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --cairo_path ./src --abi build/contract_account_abi.json
	starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --account_contract --output build/externally_owned_account.json --cairo_path ./src --abi build/externally_owned_account_abi.json
	starknet-compile ./src/kakarot/accounts/proxy/proxy.cairo --output build/proxy_account.json --cairo_path ./src --abi build/proxy_account_abi.json

check:
	poetry lock --check

setup:
	poetry install

test: build-sol
	poetry run pytest tests --log-cli-level=INFO -n logical

test-no-log: build-sol
	poetry run pytest tests -n logical

test-integration: build-sol
	poetry run pytest tests/integration --log-cli-level=INFO -n logical

test-unit: build-sol
	poetry run pytest tests/unit --log-cli-level=INFO

run-test-log: build-sol
	poetry run pytest -k $(test) --log-cli-level=INFO -vvv

run-test: build-sol
	poetry run pytest -k $(test)

run-test-mark-log: build-sol
	poetry run pytest -m $(mark) --log-cli-level=INFO -vvv

run-test-mark: build-sol
	poetry run pytest -m $(mark)

deploy: build
	poetry run python ./scripts/deploy_kakarot.py

format:
	poetry run cairo-format -i ${cairo_files}
	poetry run black tests/.
	poetry run isort tests/.
	poetry run autoflake . -r

format-check:
	poetry run cairo-format -c ${cairo_files}
	poetry run black tests/. --check
	poetry run isort tests/. --check
	poetry run autoflake . -r -cd

clean:
	rm -rf build
	mkdir build

lint:
	amarna ./src/kakarot -o lint.sarif -rules unused-imports,dead-store,unknown-decorator,unused-arguments

format-mac:
	cairo-format src/**/*.cairo -i
	black tests/.
	isort tests/.

check-resources:
	poetry run python scripts/check_resources.py

get-blockhashes:
	poetry run python scripts/get_latest_blockhashes.py

build-sol:
	forge build --names --force

run:
	poetry run starknet-devnet --lite-mode --seed 0 --dump-on exit --dump-path devnet.pkl
