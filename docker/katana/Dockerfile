FROM --platform=$BUILDPLATFORM rust:1.70 as katana-builder

ENV STARKNET_NETWORK=KATANA

RUN apt-get update && apt-get install -y git

WORKDIR /app

RUN git clone https://github.com/dojoengine/dojo.git

WORKDIR /app/dojo

# add targets
RUN rustup target add x86_64-unknown-linux-gnu
RUN rustup target add aarch64-unknown-linux-gnu

# install compilers
RUN apt-get -y install gcc-x86-64-linux-gnu
RUN apt-get -y install gcc-aarch64-linux-gnu

# build for both targets
RUN cargo build --package katana --release --target=x86_64-unknown-linux-gnu --config target.x86_64-unknown-linux-gnu.linker=\"x86_64-linux-gnu-gcc\"
RUN cargo build --package katana --release --target=aarch64-unknown-linux-gnu --config target.aarch64-unknown-linux-gnu.linker=\"aarch64-linux-gnu-gcc\"

FROM python:3.9.13-slim-bullseye 

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD if [ "$(cat /root/.kakarot_deploy_status)" -eq 0 ]; then exit 0; else exit 1; fi

COPY --from=katana-builder /app/dojo/target/x86_64-unknown-linux-gnu/release/katana  /app/katana/x86_64-unknown-linux-gnu/release/katana 
COPY --from=katana-builder /app/dojo/target/aarch64-unknown-linux-gnu/release/katana /app/katana/aarch64-unknown-linux-gnu/release/katana 
COPY ./docker/katana/scripts /app/scripts

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential coreutils curl libgmp3-dev

RUN chmod +x scripts/run.sh
RUN chmod +x scripts/wait_and_deploy.sh

# install poetry
RUN curl -sSL https://install.python-poetry.org | python3 -

ENV PATH="$PATH:/root/.local/bin"

COPY ./pyproject.toml /app/kakarot/pyproject.toml
COPY ./poetry.lock /app/kakarot/poetry.lock
COPY ./scripts  /app/kakarot/scripts
COPY ./README.md  /app/kakarot/README.md

WORKDIR /app/kakarot
RUN poetry install

COPY . /app/kakarot

# copy example env to env so deploy script has access to necessary environment variables
RUN cp .env.example .env

RUN make build

EXPOSE 5050

WORKDIR /app/scripts
CMD [ "./run.sh" ]
