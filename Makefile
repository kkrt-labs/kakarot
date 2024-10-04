# Include .env file to get GITHUB_TOKEN
ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: build test coverage clean

KATANA_VERSION = v1.0.0-alpha.14

BUILD_DIR = build
SSJ_DIR = $(BUILD_DIR)/ssj

build-ssj:
	@echo "Building Kakarot SSJ"
	@mkdir -p $(SSJ_DIR)
	@cd cairo/kakarot-ssj && scarb build -p contracts && find target/dev -type f -name '*contracts*' | grep -vE 'test|mock|Mock' | xargs -I {} cp {} ../../$(SSJ_DIR)

build: build-ssj
	uv run compile

deploy: build build-sol
	uv run deploy

fetch-ef-tests:
	uv run python ./kakarot_scripts/ef_tests/fetch.py

setup:
	uv sync --all-extras --dev

test-cairo-zero: deploy
	uv run pytest cairo_zero/tests/src  -m "not NoCI" --log-cli-level=INFO -n logical --seed 42
	uv run pytest tests/end_to_end --seed 42

test-unit-cairo-zero: build-sol
	uv run pytest cairo_zero/tests/src -m "not NoCI" -n logical --seed 42

test-unit-cairo:
	@PACKAGE="$(word 2,$(MAKECMDGOALS))" && \
	FILTER="$(word 3,$(MAKECMDGOALS))" && cd cairo/kakarot-ssj && \
	if [ -z "$$PACKAGE" ] && [ -z "$$FILTER" ]; then \
		scarb test; \
	elif [ -n "$$PACKAGE" ] && [ -z "$$FILTER" ]; then \
		scarb test -p $$PACKAGE; \
	elif [ -n "$$PACKAGE" ] && [ -n "$$FILTER" ]; then \
		uv run scripts/run_filtered_tests.py scarb test -p $$PACKAGE $$FILTER; \
	else \
		echo "Usage: make test-unit-cairo [PACKAGE] [FILTER]"; \
		exit 1; \
	fi


test-end-to-end: deploy
	uv run pytest tests/end_to_end --seed 42

format:
	trunk check --fix

format-check:
	trunk check --ci

clean:
	rm -rf $(BUILD_DIR)/*.json
	rm -rf $(BUILD_DIR)/fixtures/*.json
	rm -rf $(SSJ_DIR)
	mkdir -p $(BUILD_DIR)

check-resources:
	uv run python kakarot_scripts/check_resources.py

build-sol:
	git submodule update --init --recursive
	forge build --names --force

install-katana:
	cargo install --git https://github.com/dojoengine/dojo --locked --tag "${KATANA_VERSION}" katana

run-katana:
	katana --chain-id test --validate-max-steps 6000000 --invoke-max-steps 14000000 --eth-gas-price 0 --strk-gas-price 0 --disable-fee --seed 0

run-anvil:
	anvil --block-base-fee-per-gas 1

run-nodes:
	@echo "Starting Anvil and Katana in messaging mode"
	@anvil --block-base-fee-per-gas 1 &
	@katana --chain-id test --validate-max-steps 6000000 --invoke-max-steps 14000000 --eth-gas-price 0 --strk-gas-price 0 --disable-fee --messaging .katana/messaging_config.json --seed 0
