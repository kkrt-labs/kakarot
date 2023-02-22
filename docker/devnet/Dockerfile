FROM python:3.9.13 as builder

WORKDIR /kakarot
COPY . .
RUN pip3 install poetry
RUN poetry install
RUN poetry run python ./docker/devnet/run_and_deploy.py

FROM shardlabs/starknet-devnet:0.4.6

COPY --from=builder /kakarot/devnet.pkl devnet.pkl
ENTRYPOINT ["starknet-devnet", "--host", "0.0.0.0", "--port", "5050", "--load-path", "devnet.pkl"]
