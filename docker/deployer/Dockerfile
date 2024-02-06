# trunk-ignore-all(hadolint/DL4006)
# trunk-ignore-all(checkov/CKV_DOCKER_3)
# trunk-ignore-all(terrascan/AC_DOCKER_0002)
# trunk-ignore-all(hadolint/DL3008)
# trunk-ignore-all(terrascan/AC_DOCKER_0047)
FROM python:3.9.13 as builder

HEALTHCHECK NONE

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    apt-transport-https \
    ca-certificates \
    wget \
    tar \
    unzip \
    jq \
    && rm -rf /var/lib/apt/lists/*

ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=${GITHUB_TOKEN}

# install poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="$PATH:/root/.local/bin"
RUN poetry config virtualenvs.create false

# install dependencies
WORKDIR /build
COPY poetry.lock .
COPY pyproject.toml .
COPY scripts ./scripts
COPY README.md .
COPY tests ./tests
RUN poetry install
# split install in two steps to leverage docker cache
COPY . .
RUN make setup && make build

FROM python:3.9.13-slim-bullseye

WORKDIR /app/kakarot

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    apt-transport-https \
    ca-certificates \
    gcc \
    libgmp-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL https://install.python-poetry.org | python3 -

ENV PATH="$PATH:/root/.local/bin"
ENV PYTHONPATH="/app/kakarot"
RUN poetry config virtualenvs.create false

# Copy only necessary artifacts from the builder stage
# Correctly copy the deploy_kakarot.py script to its intended location
COPY --from=builder /build/scripts/ /app/kakarot/scripts/
COPY --from=builder /build/build /app/kakarot/build/
COPY --from=builder /build/Makefile /app/kakarot/
COPY --from=builder /build/tests /app/kakarot/tests/

# Cairo Smart contracts are used in deploy_kakarot.py
# To limit the probability of this Dockerfile to break, we copy the entire src and not individual files
COPY --from=builder /build/src /app/kakarot/src/

# Copy poetry lock and toml
COPY --from=builder /build/poetry.lock /app/kakarot/
COPY --from=builder /build/pyproject.toml /app/kakarot/

# Copy foundry.toml
COPY --from=builder /build/foundry.toml /app/kakarot/

RUN poetry install

# Deploy kakarot
CMD ["python", "scripts/deploy_kakarot.py"]
