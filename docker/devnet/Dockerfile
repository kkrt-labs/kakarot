FROM shardlabs/starknet-devnet:0.4.6

COPY ./deployments/devnet/devnet.pkl devnet.pkl
ENV STARKNET_DEVNET_CAIRO_VM=rust
ENTRYPOINT ["starknet-devnet", "--host", "0.0.0.0", "--port", "5050", "--load-path", "devnet.pkl", "--disable-rpc-request-validation", "--timeout", "300"]
