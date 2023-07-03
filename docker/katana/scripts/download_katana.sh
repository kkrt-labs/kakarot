# Conditionally download different binaries based on architecture
if [ "$(uname -m)" = "x86_64" ]; then \
      wget https://github.com/dojoengine/dojo/releases/download/nightly-a319f1cf3fc8ab106c7147452a3b19b572b17f0d/dojo_nightly_linux_amd64.tar.gz
      tar -xvf dojo_nightly_linux_amd64.tar.gz -C /app/
    elif [ "$(uname -m)" = "aarch64" ]; then \
      wget https://github.com/dojoengine/dojo/releases/download/nightly-a319f1cf3fc8ab106c7147452a3b19b572b17f0d/dojo_nightly_linux_arm64.tar.gz
      tar -xvf dojo_nightly_linux_arm64.tar.gz -C /app/
    else \
      echo "Unsupported architecture: $BUILDARCH"; \
      exit 1; \
    fi