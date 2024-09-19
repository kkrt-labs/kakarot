# Include .env file to get GITHUB_TOKEN
ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: build test coverage clean

# 154615699 corresponds to release v0.1.7 of Kakarot SSJ.
KKRT_SSJ_RELEASE_ID = 154615699
# Kakarot SSJ artifacts for precompiles.
KKRT_SSJ_BUILD_ARTIFACT_URL = $(shell curl -L https://api.github.com/repos/kkrt-labs/kakarot-ssj/releases/${KKRT_SSJ_RELEASE_ID} | jq -r '.assets[0].browser_download_url')
KATANA_VERSION = v1.0.0-alpha.11
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

BUILD_DIR = build
SSJ_DIR = $(BUILD_DIR)/ssj
SSJ_ZIP = dev-artifacts.zip

build: $(SSJ_DIR) check
	poetry run python ./kakarot_scripts/compile_kakarot.py

check:
	poetry check --lock

$(SSJ_DIR): $(SSJ_ZIP)
	rm -rf $(SSJ_DIR)
	mkdir -p $(SSJ_DIR)
	unzip -o $(SSJ_ZIP) -d $(SSJ_DIR)
	rm -f $(SSJ_ZIP)

$(SSJ_ZIP):
	curl -sL -o $(SSJ_ZIP) "$(KKRT_SSJ_BUILD_ARTIFACT_URL)"

fetch-ef-tests:
	poetry run python ./kakarot_scripts/ef_tests/fetch.py

setup: fetch-ssj-artifacts
	poetry install

test: deploy
	poetry run pytest tests/src -m "not NoCI" --log-cli-level=INFO -n logical --seed 42
	poetry run pytest tests/end_to_end --seed 42

test-unit: build-sol
	poetry run pytest tests/src -m "not NoCI" -n logical --seed 42

test-end-to-end: deploy
	poetry run pytest tests/end_to_end --seed 42

deploy: build build-sol
	poetry run python ./kakarot_scripts/deploy_kakarot.py

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
	poetry run python kakarot_scripts/check_resources.py

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
