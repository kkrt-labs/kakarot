# Conditionally download different binaries based on architecture
if [ "$(uname -m)" = "x86_64" ]; then \
      wget https://github.com/dojoengine/dojo/releases/download/nightly-efb3cf6841b679fd94204ace10147a8e84c5fc8a/dojo_nightly_linux_amd64.tar.gz
      tar -xvf dojo_nightly_linux_amd64.tar.gz -C /app/
    elif [ "$(uname -m)" = "aarch64" ]; then \
      wget https://github.com/dojoengine/dojo/releases/download/nightly-efb3cf6841b679fd94204ace10147a8e84c5fc8a/dojo_nightly_linux_arm64.tar.gz
      tar -xvf dojo_nightly_linux_arm64.tar.gz -C /app/
    else \
      echo "Unsupported architecture: $BUILDARCH"; \
      exit 1; \
    fi