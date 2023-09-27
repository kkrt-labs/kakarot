.PHONY: build test coverage

pull-ef-tests: .gitmodules
	git submodule update --init --recursive

build: check
	$(MAKE) clean
	poetry run python ./scripts/compile_kakarot.py

check:
	poetry lock --check

setup:
	poetry install

test: build-sol deploy
	poetry run pytest tests/integration tests/src -m "not EFTests" --log-cli-level=INFO -n logical
	poetry run pytest tests/end_to_end

test-no-log: build-sol deploy pull-ef-tests
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
	cargo install --git https://github.com/dojoengine/dojo --rev 1d3f47dfcade922449f2499cb40c3fc6033134ae katana@0.2.1

run-katana:
	katana --validate-max-steps 16777216 --invoke-max-steps 16777216

run-katana-with-dump:
	katana --validate-max-steps 16777216 --invoke-max-steps 16777216 --dump-state ./kakarot-katana-dump
