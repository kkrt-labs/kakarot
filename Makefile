.PHONY: build test

build:
	$(MAKE) clean
	starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --disable_hint_validation --cairo_path ./src
	starknet-compile ./src/kakarot/accounts/contract/contract_account.cairo --output build/contract_account.json --disable_hint_validation --cairo_path ./src
	starknet-compile ./src/kakarot/accounts/eoa/externally_owned_account.cairo --output build/externally_owned_account.json --disable_hint_validation --cairo_path ./src
	starknet-compile ./src/kakarot/accounts/registry/account_registry.cairo --output build/account_registry.json --disable_hint_validation --cairo_path ./src

setup:
	pip install -r requirements.txt

test:
	pytest -s --log-cli-level=INFO

test-integration:
	pytest tests/integrations -s --log-cli-level=INFO

test-units:
	pytest tests/units -s --log-cli-level=INFO

format:
	cairo-format src/**/*.cairo -i

format-check:
	cairo-format src/**/*.cairo -c

clean:
	rm -rf build
	mkdir build