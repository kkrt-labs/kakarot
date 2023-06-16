FROM --platform=$BUILDPLATFORM rust:1.70 as katana

RUN apt-get update && apt-get install -y git

WORKDIR /app

RUN git clone https://github.com/dojoengine/dojo.git

WORKDIR /app/dojo

RUN cargo build --package katana --release

FROM python:3.9.13-slim-bullseye 

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD if [ "$(cat /root/.kakarot_deploy_status)" -eq 0 ]; then exit 0; else exit 1; fi

COPY --from=katana /app/dojo/target/release/katana /app/katana
COPY ./docker/katana/scripts /app/scripts

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential coreutils curl libgmp3-dev

RUN chmod +x scripts/run.sh
RUN chmod +x scripts/wait_and_deploy.sh

COPY ./docker/katana/cairo/requirements.txt ./requirements.txt

RUN pip3 install -r requirements.txt

# install poetry
RUN curl -sSL https://install.python-poetry.org | python3 -

ENV PATH="$PATH:/root/.local/bin"

COPY . ./kakarot
WORKDIR /app/kakarot

RUN poetry install
RUN make build

EXPOSE 5050

WORKDIR /app/scripts
CMD [ "./run.sh" ]
