build:
	rm -rf build
	mkdir build
	starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --disable_hint_validation --cairo_path ./src

setup:
	pip install -r requirements.txt

test:
	pytest -s

test-integration:
	pytest tests/integrations -s

test-units:
	pytest tests/units -s

