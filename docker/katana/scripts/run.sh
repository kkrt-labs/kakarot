#!/bin/bash

# run ./wait_and_deploy.sh in background
nohup ./wait_and_deploy.sh & > /dev/null

# Conditionally run different binaries based on architecture
if [ "$(uname -m)" = "x86_64" ]; then \
      /app/katana/x86_64-unknown-linux-gnu/release/katana; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
      /app/katana/aarch64-unknown-linux-gnu/release/katana; \
    else \
      echo "Unsupported architecture: $BUILDARCH"; \
      exit 1; \
    fi
