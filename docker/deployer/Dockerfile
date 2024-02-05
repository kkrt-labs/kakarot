# trunk-ignore-all(terrascan/AC_DOCKER_0047)
# trunk-ignore-all(hadolint/DL4006)
# trunk-ignore-all(checkov/CKV_DOCKER_3)
FROM python:3.9.13 as builder

HEALTHCHECK NONE

# trunk-ignore(terrascan/AC_DOCKER_0002)
# trunk-ignore(hadolint/DL3008)
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

FROM python:3.9.13

WORKDIR /app/kakarot

# trunk-ignore(hadolint/DL3008)
# trunk-ignore(terrascan/AC_DOCKER_0002)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    apt-transport-https \
    ca-certificates \
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

# Used in deploy_kakarot.py
COPY --from=builder /build/src/kakarot/kakarot.cairo /app/kakarot/src/kakarot/
COPY --from=builder /build/src/kakarot/accounts /app/kakarot/src/kakarot/accounts/
COPY --from=builder /build/src/kakarot/precompiles /app/kakarot/src/kakarot/precompiles/
COPY --from=builder /build/src/utils/OpenzeppelinAccount.cairo /app/kakarot/src/utils/

# Copy poetry lock and toml
COPY --from=builder /build/poetry.lock /app/kakarot/
COPY --from=builder /build/pyproject.toml /app/kakarot/

RUN poetry install

# Deploy kakarot
CMD ["python", "scripts/deploy_kakarot.py"]
