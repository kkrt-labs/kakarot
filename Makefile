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
KATANA_VERSION = v1.0.0-alpha.13
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

BUILD_DIR = build
SSJ_DIR = $(BUILD_DIR)/ssj
SSJ_ZIP = dev-artifacts.zip

build: $(SSJ_DIR)
	uv run compile

deploy: build build-sol
	uv run deploy

$(SSJ_DIR): $(SSJ_ZIP)
	rm -rf $(SSJ_DIR)
	mkdir -p $(SSJ_DIR)
	unzip -o $(SSJ_ZIP) -d $(SSJ_DIR)
	rm -f $(SSJ_ZIP)

$(SSJ_ZIP):
	curl -sL -o $(SSJ_ZIP) "$(KKRT_SSJ_BUILD_ARTIFACT_URL)"

fetch-ef-tests:
	poetry run python ./kakarot_scripts/ef_tests/fetch.py

setup:
	uv sync --all-extras --dev

test: deploy
	uv run pytest tests/src -m "not NoCI" --log-cli-level=INFO -n logical --seed 42
	uv run pytest tests/end_to_end --seed 42

test-unit: build-sol
	uv run pytest tests/src -m "not NoCI" -n logical --seed 42

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
