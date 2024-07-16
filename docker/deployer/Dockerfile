# trunk-ignore-all(hadolint/DL4006)
# trunk-ignore-all(checkov/CKV_DOCKER_3)
# trunk-ignore-all(hadolint/DL3008)

###########################################
# Base image used by builder and deployer
###########################################
FROM python:3.10.14-slim-bookworm as base

HEALTHCHECK NONE

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    VIRTUAL_ENV=/app/kakarot/.venv \
    PATH="/app/kakarot/.venv/bin:/root/.local/bin:$PATH"

RUN --mount=type=cache,target=/root/.cache \
    curl -sSL https://install.python-poetry.org | python3 -

WORKDIR /app/kakarot

############################################
# Kakarot builder
############################################
FROM base as builder

ENV PATH="$PATH:/root/.local/bin:/root/.foundry/bin"
RUN curl -L https://foundry.paradigm.xyz -o foundry.sh \
    && chmod +x foundry.sh \
    && ./foundry.sh \
    && foundryup

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    wget \
    tar \
    unzip \
    jq \
    gcc \
    libgmp-dev \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=${GITHUB_TOKEN}

# install dependencies
COPY poetry.lock .
COPY pyproject.toml .
COPY kakarot_scripts ./kakarot_scripts
COPY README.md .
COPY tests ./tests

RUN --mount=type=cache,target=/root/.cache \
    poetry install

# split install in two steps to leverage docker cache
COPY . .
RUN curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh -s -- -v 0.7.0
RUN --mount=type=cache,target=/root/.cache \
    make fetch-ssj-artifacts && make build && make build-cairo1 && make build-sol


############################################
# Kakarot deployer
############################################
FROM base as deployer

COPY --from=builder /app/kakarot/build ./build/
COPY --from=builder /app/kakarot/kakarot_scripts/ ./kakarot_scripts/
COPY --from=builder /app/kakarot/tests ./tests/

# Cairo Smart contracts are used in deploy_kakarot.py
# To limit the probability of this Dockerfile to break, we copy the entire src and not individual files
COPY --from=builder /app/kakarot/src ./src/

# Default Solidity contracts are also used in deploy_kakarot.py
COPY --from=builder /app/kakarot/solidity_contracts ./solidity_contracts/

COPY --from=builder /app/kakarot/Makefile .
COPY --from=builder /app/kakarot/poetry.lock .
COPY --from=builder /app/kakarot/pyproject.toml .
COPY --from=builder /app/kakarot/foundry.toml .
COPY --from=builder /app/kakarot/README.md .

RUN --mount=type=cache,target=/root/.cache \
    poetry install --without dev

# Deploy kakarot
CMD ["python", "kakarot_scripts/deploy_kakarot.py"]
