# %% Imports
import asyncio
import json
import logging
import secrets

import boto3

from kakarot_scripts.utils.starknet import deploy_starknet_account

# Initialize AWS Secrets Manager client
client = boto3.client("secretsmanager")
SECRET_NAME = "relayers_private_key"

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Get private key
def get_private_key():
    """Retrieve or generate a private key."""
    try:
        response = client.get_secret_value(SecretId=SECRET_NAME)
        return response["SecretString"], response["ARN"]
    except client.exceptions.ResourceNotFoundException:
        private_key = hex(secrets.randbits(256))
        response = client.update_secret(SecretId=SECRET_NAME, SecretString=private_key)
        secret_id = response["ARN"]
        return secret_id, private_key


# %% Deploy accounts
async def main():
    """Deploy 'num_accounts' accounts and store the private keys in AWS Secrets Manager."""
    num_accounts = 30  # Number of accounts to create
    amount = 0.1  # Initial funding amount for each relayer account
    accounts_data = []
    private_key, secret_id = get_private_key()

    accounts_data = [
        {
            "secret_id": secret_id,
            "address": (
                await deploy_starknet_account(private_key=private_key, amount=amount)
            )["address"],
        }
        for _ in range(num_accounts)
    ]
    logger.info(f"{num_accounts} accounts deployed and saved to 'oz_accounts.json'")

    # Save the account data to a JSON file
    with open("kakarot_scripts/data/oz_accounts.json", "w") as json_file:
        json.dump(accounts_data, json_file, indent=2)


# %% Run
if __name__ == "__main__":
    # Deploy the accounts and store private keys in AWS Secrets Manager
    asyncio.run(main())
