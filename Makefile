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

build: check
	$(MAKE) clean
	poetry run python ./scripts/compile_kakarot.py

check:
	poetry check --lock

setup: $(EF_TESTS_DIR)
	poetry install

test: build-sol deploy
	poetry run tests/src --log-cli-level=INFO -n logical
	poetry run pytest tests/end_to_end

test-no-log: build-sol deploy
	poetry run tests/src -n logical
	poetry run pytest tests/end_to_end

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

build-sol: .gitmodules
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
