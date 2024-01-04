# trunk-ignore-all(terrascan/AC_DOCKER_0047)
# trunk-ignore-all(hadolint/DL4006)
# trunk-ignore-all(hadolint/DL3059)
FROM python:3.9.13

HEALTHCHECK NONE

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

USER appuser

# install poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="$PATH:/root/.local/bin"
RUN poetry config virtualenvs.create false

# install dependencies
WORKDIR /app/kakarot
COPY poetry.lock .
COPY pyproject.toml .
COPY scripts ./scripts
COPY README.md .
RUN mkdir tests \
    touch tests/__init__.py \
    poetry install
# split install in two steps to leverage docker cache
COPY . .
RUN poetry install

# Build contracts
RUN python scripts/compile_kakarot.py

# Deploy kakarot
CMD ["python", "scripts/deploy_kakarot.py"]
