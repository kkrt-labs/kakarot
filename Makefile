# The release tag of https://github.com/ethereum/tests to use for EF tests
EF_TESTS_TAG := v12.4
EF_TESTS_URL := https://github.com/ethereum/tests/archive/refs/tags/$(EF_TESTS_TAG).tar.gz
EF_TESTS_DIR := ./tests/ef_tests/test_data

# Downloads and unpacks Ethereum Foundation tests in the `$(EF_TESTS_DIR)` directory.
# Requires `wget` and `tar`
$(EF_TESTS_DIR):
	mkdir -p $(EF_TESTS_DIR)
	wget $(EF_TESTS_URL) -O ethereum-tests.tar.gz
	tar -xzf ethereum-tests.tar.gz --strip-components=1 -C $(EF_TESTS_DIR)
	rm ethereum-tests.tar.gz


.PHONY: build test coverage $(EF_TESTS_DIR)

# Include .env file to get GITHUB_TOKEN
ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: build test coverage

# Kakarot SSJ artifacts for precompiles
KKRT_SSJ_ARTIFACTS_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "https://api.github.com/repos/kkrt-labs/kakarot-ssj/actions/workflows/artifacts.yml/runs?per_page=1&branch=main&event=push&status=success" | jq -r '.workflow_runs[0].artifacts_url')
KKRT_SSJ_BUILD_ARTIFACT_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_SSJ_ARTIFACTS_URL)" | jq -r '.artifacts[] | select(.name=="dev-artifacts").url')/zip

build: check
	$(MAKE) clean
	poetry run python ./scripts/compile_kakarot.py

check:
	poetry check --lock

# This action fetches the latest Kakarot SSJ (Cairo compiler version >=2) artifacts
# from the main branch and unzips them into the build/ssj directory.
# This is required because Kakarot Zero (Cairo Zero, compiler version <1) uses some SSJ Cairo programs.
# Most notably for precompiles.
fetch-ssj-artifacts:
	rm -rf build/ssj
	mkdir -p build/ssj
	@curl -sL -o dev-artifacts.zip -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_SSJ_BUILD_ARTIFACT_URL)"
	unzip -o dev-artifacts.zip -d build/ssj
	rm -f dev-artifacts.zip

setup: fetch-ssj-artifacts
	poetry install

test: build-sol deploy
	poetry run pytest tests/src -m "not EFTests" --log-cli-level=INFO -n logical
	poetry run pytest tests/end_to_end

test-unit:
	poetry run pytest tests/src -n logical

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
	curl -L https://install.dojoengine.org | bash
	~/.config/.dojo/bin/dojoup -v 0.6.0-alpha.0
	echo $PATH

run-katana: install-katana
	katana --validate-max-steps 16777216 --invoke-max-steps 16777216 --gas-price 0 --disable-fee
