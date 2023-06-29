FROM python:3.9.13-slim-bullseye 

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD if [ "$(cat /root/.kakarot_deploy_status)" -eq 0 ]; then exit 0; else exit 1; fi

COPY ./docker/katana/scripts /app/scripts

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential coreutils libgmp3-dev wget curl

RUN chmod +x scripts/download_katana.sh
RUN chmod +x scripts/run.sh
RUN chmod +x scripts/wait_and_deploy.sh

# install poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="$PATH:/root/.local/bin"

# install files required to install dependencies
COPY ./pyproject.toml /app/kakarot/pyproject.toml
COPY ./poetry.lock /app/kakarot/poetry.lock
COPY ./scripts  /app/kakarot/scripts
COPY ./README.md  /app/kakarot/README.md

# install dependencies
WORKDIR /app/kakarot
RUN poetry install

# download katana
RUN /app/scripts/download_katana.sh

# compile kakarot
COPY . /app/kakarot
RUN make build

EXPOSE 5050

# run katana and deploy kakarot
WORKDIR /app/scripts
CMD [ "./run.sh" ]
