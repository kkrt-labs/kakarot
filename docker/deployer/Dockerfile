# trunk-ignore-all(hadolint/DL4006)
# trunk-ignore-all(checkov/CKV_DOCKER_3)
# trunk-ignore-all(hadolint/DL3008)

###########################################
# Base image used by builder and deployer
###########################################
FROM python:3.9.13-slim-bullseye as base

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1

RUN --mount=type=cache,target=/root/.cache \
    curl -sSL https://install.python-poetry.org | python3 -

ENV PATH="$PATH:/root/.local/bin"

WORKDIR /app/kakarot

############################################
# Kakarot builder
############################################
FROM base as builder

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
COPY scripts ./scripts
COPY README.md .
COPY tests ./tests

RUN --mount=type=cache,target=/root/.cache \
    poetry install

# split install in two steps to leverage docker cache
COPY . .
RUN --mount=type=cache,target=/root/.cache \
    make setup && make build

############################################
# Kakarot deployer
############################################
FROM base as deployer

ENV VIRTUAL_ENV=/app/kakarot/.venv \
    PATH="/app/kakarot/.venv/bin:$PATH"

# Copy only necessary artifacts from the builder stage
COPY --from=builder /app/kakarot/.venv/bin ./.venv/bin
COPY --from=builder /app/kakarot/.venv/lib ./.venv/lib
COPY --from=builder /app/kakarot/.venv/share ./.venv/share
COPY --from=builder /app/kakarot/.venv/pyvenv.cfg ./.venv/

COPY --from=builder /app/kakarot/build ./build/
COPY --from=builder /app/kakarot/scripts/ ./scripts/
COPY --from=builder /app/kakarot/tests ./tests/

# Cairo Smart contracts are used in deploy_kakarot.py
# To limit the probability of this Dockerfile to break, we copy the entire src and not individual files
COPY --from=builder /app/kakarot/src ./src/

COPY --from=builder /app/kakarot/Makefile .
COPY --from=builder /app/kakarot/poetry.lock .
COPY --from=builder /app/kakarot/pyproject.toml .
COPY --from=builder /app/kakarot/foundry.toml .
COPY --from=builder /app/kakarot/README.md .

RUN --mount=type=cache,target=/root/.cache \
    poetry install

# Deploy kakarot
CMD ["python", "scripts/deploy_kakarot.py"]
