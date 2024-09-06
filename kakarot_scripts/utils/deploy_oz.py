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


# %% Store secret in AWS
def store_secret_in_aws(secret_name, private_key):
    """Store the private key in AWS Secrets Manager. If the secret already exists, it will be updated."""
    try:
        response = client.update_secret(SecretId=secret_name, SecretString=private_key)
        secret_id = response["ARN"]
    except client.exceptions.ResourceNotFoundException:
        response = client.create_secret(Name=secret_name, SecretString=private_key)
        secret_id = response["ARN"]
    return secret_id


# %% Save accounts to JSON
def save_accounts_to_json(
    accounts_data, filename="kakarot_scripts/data/oz_accounts.json"
):
    """Save the account data to a JSON file."""
    with open(filename, "w") as json_file:
        json.dump(accounts_data, json_file, indent=2)


# %% Get private key
def get_private_key():
    """Retrieve or generate a private key."""
    try:
        response = client.get_secret_value(SecretId=SECRET_NAME)
        return {response["SecretString"], response["ARN"]}
    except client.exceptions.ResourceNotFoundException:
        private_key = hex(secrets.randbits(256))
        secret_id = store_secret_in_aws(SECRET_NAME, private_key)
        return {secret_id, private_key}


# %% Deploy accounts
async def main():
    """Deploy 'num_accounts' accounts and store the private keys in AWS Secrets Manager."""
    num_accounts = 30  # Number of accounts to create
    amount = 0.1  # Initial funding amount for each relayer account
    accounts_data = []
    private_key, secret_id = get_private_key()

    for _ in range(num_accounts):
        response = await deploy_starknet_account(private_key=private_key, amount=amount)
        accounts_data.append({"secret_id": secret_id, "address": response["address"]})

    logger.info(f"{num_accounts} accounts deployed and saved to 'oz_accounts.json'")

    # Save the account data to a JSON file
    save_accounts_to_json(accounts_data)


# %% Run
if __name__ == "__main__":
    # Deploy the accounts and store private keys in AWS Secrets Manager
    asyncio.run(main())
