# trunk-ignore-all(terrascan/AC_DOCKER_0047)
# trunk-ignore-all(hadolint/DL4006)
# trunk-ignore-all(checkov/CKV_DOCKER_3)
FROM python:3.9.13

HEALTHCHECK NONE

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
COPY tests ./tests
RUN poetry install
# split install in two steps to leverage docker cache
COPY . .

# Build contracts
RUN python scripts/compile_kakarot.py

# Deploy kakarot
CMD ["python", "scripts/deploy_kakarot.py"]
