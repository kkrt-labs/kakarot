# Include .env file to get GITHUB_TOKEN
ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: build test coverage clean

# 176384150 corresponds to release v0.1.13 of Kakarot SSJ.
KKRT_SSJ_RELEASE_ID = 176384150
# Kakarot SSJ artifacts for precompiles.
KKRT_SSJ_BUILD_ARTIFACT_URL = $(shell curl -L https://api.github.com/repos/kkrt-labs/kakarot-ssj/releases/${KKRT_SSJ_RELEASE_ID} | jq -r '.assets[0].browser_download_url')
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

BUILD_DIR = build
SSJ_DIR = $(BUILD_DIR)/ssj
SSJ_ZIP = dev-artifacts.zip

$(SSJ_DIR): $(SSJ_ZIP)
	rm -rf $(SSJ_DIR)
	mkdir -p $(SSJ_DIR)
	unzip -o $(SSJ_ZIP) -d $(SSJ_DIR)
	rm -f $(SSJ_ZIP)

$(SSJ_ZIP):
	curl -sL -o $(SSJ_ZIP) "$(KKRT_SSJ_BUILD_ARTIFACT_URL)"

# Accepts "katana" as an argument to setup only Katana (for CI).
setup:
	@python kakarot_scripts/setup/setup.py $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
	uv sync --all-extras --dev
katana: ;

build: $(SSJ_DIR)
	uv run compile

deploy: build build-sol
	uv run deploy

fetch-ef-tests:
	uv run ef_tests

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

run-katana:
	katana --chain-id test --validate-max-steps 1000000 --invoke-max-steps 9000000 --eth-gas-price 0 --strk-gas-price 0 --disable-fee --seed 0

run-anvil:
	anvil --block-base-fee-per-gas 1

run-nodes:
	@echo "Starting Anvil and Katana in messaging mode"
	@anvil --block-base-fee-per-gas 1 &
	@katana --chain-id test --validate-max-steps 1000000 --invoke-max-steps 9000000 --eth-gas-price 0 --strk-gas-price 0 --disable-fee --messaging .katana/messaging_config.json --seed 0
