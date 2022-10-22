build:
	mkdir build
	starknet-compile ./src/kakarot/kakarot.cairo --output build/kakarot.json --disable_hint_validation

setup:
	pip install -r requirements.txt

test:
	pytest -s

integration:
	pytest tests/integrations -s

units:
	pytest tests/units -s

