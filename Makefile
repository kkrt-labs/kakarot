.PHONY: build test coverage
cairo_files = $(shell find ./src ./tests -type f -name "*.cairo")

build: check
	$(MAKE) clean
	poetry run python ./scripts/compile_kakarot.py

check:
	poetry lock --check

setup:
	poetry install

test: build-sol
	poetry run pytest tests --log-cli-level=INFO -n logical

test-no-log: build-sol
	poetry run pytest tests -n logical

test-integration: build-sol
	poetry run pytest tests/integration --log-cli-level=INFO -n logical

test-unit:
	poetry run pytest tests/src --log-cli-level=INFO

run-test-log: build-sol
	poetry run pytest -k $(test) --log-cli-level=INFO -vvv

run-test: build-sol
	poetry run pytest -k $(test)

run-test-mark-log: build-sol
	poetry run pytest -m $(mark) --log-cli-level=INFO -vvv -s

run-test-mark-debug: build-sol
	poetry run pytest -m $(mark) --log-cli-level=INFO -vvv -s --pdb

run-test-mark: build-sol
	poetry run pytest -m $(mark)

deploy: build
	poetry run python ./scripts/deploy_kakarot.py

format:
	poetry run cairo-format -i ${cairo_files}
	poetry run black tests/. scripts/.
	poetry run isort tests/. scripts/.
	poetry run autoflake . -r

format-check:
	poetry run cairo-format -c ${cairo_files}
	poetry run black tests/. --check
	poetry run isort tests/. --check
	poetry run autoflake . -r -cd

clean:
	rm -rf build
	mkdir build

lint:
	amarna ./src/kakarot -o lint.sarif -rules unused-imports,dead-store,unknown-decorator,unused-arguments

format-mac:
	cairo-format src/**/*.cairo -i
	black tests/.
	isort tests/.

check-resources:
	poetry run python scripts/check_resources.py

get-blockhashes:
	poetry run python scripts/get_latest_blockhashes.py

build-sol:
	forge build --names --force

run:
	mkdir -p deployments/starknet-devnet
	poetry run starknet-devnet --lite-mode --seed 0 --dump-on exit --dump-path deployments/starknet-devnet/devnet.pkl --disable-rpc-request-validation --timeout 600
