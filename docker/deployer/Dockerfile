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


# Install asdf for multiple scarb versions
RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git "$HOME/.asdf" && \
    echo ". $HOME/.asdf/asdf.sh" >> "$HOME/.bashrc" && \
    echo ". $HOME/.asdf/asdf.sh" >> "$HOME/.profile"

SHELL ["/bin/bash", "-c"]
RUN source "$HOME/.asdf/asdf.sh" && asdf plugin add scarb && asdf install scarb 0.7.0  && asdf install scarb 2.6.5


RUN --mount=type=cache,target=/root/.cache \
    source "$HOME/.asdf/asdf.sh" && make fetch-ssj-artifacts && make build && make build-sol


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
