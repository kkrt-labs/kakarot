# Include .env file to get GITHUB_TOKEN
ifneq ("$(wildcard .env)","")
	include .env
endif

.PHONY: build test coverage

# Kakarot SSJ artifacts for precompiles
KKRT_SSJ_ARTIFACTS_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "https://api.github.com/repos/kkrt-labs/kakarot-ssj/actions/workflows/artifacts.yml/runs?per_page=1&branch=main&event=push&status=success" | jq -r '.workflow_runs[0].artifacts_url')
KKRT_SSJ_BUILD_ARTIFACT_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_SSJ_ARTIFACTS_URL)" | jq -r '.artifacts[] | select(.name=="dev-artifacts").url')/zip

pull-ef-tests: .gitmodules
	git submodule update --init --recursive

build: check
	$(MAKE) clean
	poetry run python ./scripts/compile_kakarot.py

check:
	poetry check --lock

fetch-ssj-artifacts:
	rm -rf build/ssj
	mkdir -p build/ssj
	@curl -sL -o dev-artifacts.zip -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_SSJ_BUILD_ARTIFACT_URL)"
	unzip -o dev-artifacts.zip -d build/ssj
	rm -f dev-artifacts.zip

setup: fetch-ssj-artifacts
	poetry install

test: build-sol deploy
	poetry run pytest tests/integration tests/src -m "not EFTests" --log-cli-level=INFO -n logical
	poetry run pytest tests/end_to_end

test-no-log: build-sol deploy
	poetry run pytest tests/integration tests/src -m "not EFTests" -n logical
	poetry run pytest tests/end_to_end

test-integration: build-sol
	poetry run pytest tests/integration -m "not EFTests"  --log-cli-level=INFO -n logical

test-unit:
	poetry run pytest tests/src --log-cli-level=INFO

test-end-to-end: deploy
	poetry run pytest tests/end_to_end --log-cli-level=INFO

run-test-log: build-sol
	poetry run pytest -k $(test) -m "not EFTests" --log-cli-level=INFO -vvv -s

run-test: build-sol
	poetry run pytest -k $(test) -m "not EFTests"

run-test-mark-log: build-sol
	poetry run pytest -m $(mark) --log-cli-level=INFO -vvv -s

run-test-mark: build-sol
	poetry run pytest -m $(mark)

deploy: build
	poetry run python ./scripts/deploy_kakarot.py

format:
	trunk check --fix

format-check:
	trunk check --ci

clean:
	rm -rf build
	mkdir build

check-resources:
	poetry run python scripts/check_resources.py

get-blockhashes:
	poetry run python scripts/get_latest_blockhashes.py

build-sol:
	forge build --names --force

run:
	mkdir -p deployments/starknet-devnet
	docker run -p 5050:5050 shardlabs/starknet-devnet-rs --seed 0

install-katana:
	cargo install --git https://github.com/dojoengine/dojo --locked --rev e0054e7 katana

run-katana:
	katana --validate-max-steps 16777216 --invoke-max-steps 16777216

run-katana-with-dump:
	katana --validate-max-steps 16777216 --invoke-max-steps 16777216 --dump-state ./kakarot-katana-dump
