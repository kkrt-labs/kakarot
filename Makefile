# Include .env file to get GITHUB_TOKEN
ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: build test coverage

# Kakarot SSJ artifacts for precompiles
KKRT_SSJ_BUILD_ARTIFACT_URL = $(shell curl -L https://api.github.com/repos/kkrt-labs/kakarot-ssj/releases/latest | jq -r '.assets[0].browser_download_url')

build: check
	$(MAKE) clean
	poetry run python ./scripts/compile_kakarot.py

check:
	poetry check --lock

fetch-ef-tests:
	poetry run python ./scripts/ef_tests/fetch.py

# This action fetches the latest Kakarot SSJ (Cairo compiler version >=2) artifacts
# from the main branch and unzips them into the build/ssj directory.
# This is required because Kakarot Zero (Cairo Zero, compiler version <1) uses some SSJ Cairo programs.
# Most notably for precompiles.
fetch-ssj-artifacts:
	rm -rf build/ssj
	mkdir -p build/ssj
	@curl -sL -o dev-artifacts.zip "$(KKRT_SSJ_BUILD_ARTIFACT_URL)"
	unzip -o dev-artifacts.zip -d build/ssj
	rm -f dev-artifacts.zip

setup: fetch-ssj-artifacts
	poetry install

test: build-sol deploy
	poetry run pytest tests/src -m "not NoCI" --log-cli-level=INFO -n logical
	poetry run pytest tests/end_to_end

test-unit:
	poetry run pytest tests/src -m "not NoCI" -n logical

test-end-to-end: build-sol deploy
	poetry run pytest tests/end_to_end

deploy: build
	poetry run python ./scripts/deploy_kakarot.py

format:
	trunk check --fix

format-check:
	trunk check --ci

clean:
	rm -rf build/*.json
	rm -rf build/fixtures/*.json
	mkdir -p build

check-resources:
	poetry run python scripts/check_resources.py

build-sol:
	git submodule update --init --recursive
	forge build --names --force

install-katana:
	cargo install --git https://github.com/dojoengine/dojo --locked --rev fe8f233 katana

run-katana:
	katana --validate-max-steps 16777216 --invoke-max-steps 16777216 --gas-price 0 --disable-fee
