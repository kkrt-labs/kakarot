install:
	bash scripts/install_hook.sh

test-unit:
	@PACKAGE="$(word 2,$(MAKECMDGOALS))" && \
	FILTER="$(word 3,$(MAKECMDGOALS))" && \
	if [ -z "$$PACKAGE" ] && [ -z "$$FILTER" ]; then \
		scarb test; \
	elif [ -n "$$PACKAGE" ] && [ -z "$$FILTER" ]; then \
		scarb test -p $$PACKAGE; \
	elif [ -n "$$PACKAGE" ] && [ -n "$$FILTER" ]; then \
		uv run scripts/run_filtered_tests.py $$PACKAGE $$FILTER; \
	else \
		echo "Usage: make test-unit [PACKAGE] [FILTER]"; \
		exit 1; \
	fi

%:
	@:
