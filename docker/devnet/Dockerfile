ARG DEVNET_VERSION
FROM shardlabs/starknet-devnet:${DEVNET_VERSION}

COPY ./deployments/devnet/devnet.pkl devnet.pkl
ENTRYPOINT ["starknet-devnet", "--host", "0.0.0.0", "--port", "5050", "--load-path", "devnet.pkl", "--disable-rpc-request-validation", "--timeout", "300"]
