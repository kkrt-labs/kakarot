import asyncio
import json
import logging
from argparse import ArgumentParser
from pathlib import Path

from services.external_api.client import RetryConfig
from starkware.starknet.services.api.feeder_gateway.feeder_gateway_client import (
    FeederGatewayClient,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

NETWORKS = {
    "goerli": "https://alpha4.starknet.io/feeder_gateway",  # alpha-goerli
    "mainnet": "https://alpha-mainnet.starknet.io/feeder_gateway/",  # mainnet
}


parser = ArgumentParser(description="Get block information from sequencer")
parser.add_argument(
    "--network",
    "-n",
    default="goerli",
    type=str,
    help=f"Select network, one of {list(NETWORKS.keys())}",
)
args = parser.parse_args()


async def main():
    # Instantiate a FeederGatewayClient object
    # -1 means unlimited retries
    retry_config = RetryConfig(n_retries=-1)
    feeder_gateway_client = FeederGatewayClient(
        url=NETWORKS[args.network], retry_config=retry_config
    )

    # Get the latest block
    # Sometimes get_block returns "null" as value
    # Walrus operator for assignment expression
    while (latest_block := await feeder_gateway_client.get_block()) == "null":
        continue
    logger.info(f"Latest block number: {latest_block.block_number}")

    # Get the last 256 blocks excluding the current block
    # Convert the list of blockhashes in to dictionary { block_number: block_hash }
    last_256_blocks = [
        await feeder_gateway_client.get_block(
            block_number=latest_block.block_number - i
        )
        for i in range(1, 257)
    ]
    last_256_blockhashes = {
        block.block_number: block.block_hash for block in last_256_blocks
    }

    # Dump JSON to file
    # If you want to use the created file for testing, rename that file to mock_blockhashes.json
    with open(Path("sequencer") / "blockhashes.json", "w") as file:
        context = {
            "current_block": {
                "block_number": latest_block.block_number,
                "timestamp": latest_block.timestamp,
            },
            "last_256_blocks": last_256_blockhashes,
        }
        json.dump(context, file)
    logger.info(
        f"Blockhashes retrieved from block number {min(last_256_blockhashes.keys())} to {max(last_256_blockhashes.keys())}"
    )


if __name__ == "__main__":
    asyncio.run(main())
