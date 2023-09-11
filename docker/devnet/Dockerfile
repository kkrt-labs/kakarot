ARG DEVNET_VERSION
FROM shardlabs/starknet-devnet:${DEVNET_VERSION}

LABEL org.opencontainers.image.source=https://github.com/kkrt-labs/kakarot
LABEL org.opencontainers.image.description="A starknet-devnet with pre-deployed kakarot contract"
LABEL org.opencontainers.image.licenses=MIT

COPY ./deployments/devnet/devnet.pkl devnet.pkl
ENTRYPOINT ["starknet-devnet", "--host", "0.0.0.0", "--port", "5050", "--load-path", "devnet.pkl", "--disable-rpc-request-validation", "--timeout", "300"]
