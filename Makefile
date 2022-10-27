.PHONY: build test coverage

build:
	$(MAKE) clean
	starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --disable_hint_validation --cairo_path ./src
	starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --disable_hint_validation --cairo_path ./src
	starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --output build/externally_owned_account.json --disable_hint_validation --cairo_path ./src
	starknet-compile ./src/kakarot/accounts/registry/account_registry.cairo --output build/account_registry.json --disable_hint_validation --cairo_path ./src

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

format-mac:
	cairo-format src/**/*.cairo -i
	black tests/.
	isort tests/.