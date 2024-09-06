# %% Imports
import asyncio
import json

import boto3

from kakarot_scripts.utils.starknet import declare, deploy_starknet_account

# Initialize AWS Secrets Manager client
client = boto3.client("secretsmanager")


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
        json.dump(accounts_data, json_file, indent=4)


# %% Get private key
def get_private_key(private_key):
    """Retrieve or generate a private key."""
    secret_name = "pk_oz_deploy"
    if private_key == "":
        try:
            response = client.get_secret_value(SecretId=secret_name)
            return response["SecretString"]
        except client.exceptions.ResourceNotFoundException as err:
            raise Exception(
                f"Secret {secret_name} not found. Please ensure the private key is stored in AWS Secrets Manager."
            ) from err
    else:
        try:
            response = client.update_secret(
                SecretId=secret_name, SecretString=private_key
            )
            _ = response["ARN"]
            return private_key
        except client.exceptions.ResourceNotFoundException:
            _ = store_secret_in_aws(secret_name, private_key)
            return private_key


# %% Deploy accounts
async def deploy_accounts(
    num_accounts, amount, private_key, _class_hash, secret_name_prefix="oz_account"
):
    """Deploy 'num_accounts' accounts and store the private keys in AWS Secrets Manager."""
    accounts_data = []
    private_key = get_private_key(private_key)

    class_hash = await declare("OpenzeppelinAccount")
    class_hash = _class_hash

    for i in range(num_accounts):

        # Create a unique secret name for each account
        secret_name = f"{secret_name_prefix}_{i+1}"

        # Store the private key in AWS Secrets Manager
        secret_id = store_secret_in_aws(secret_name, private_key)

        address, tx, artifact = await deploy_starknet_account(
            class_hash=int(class_hash, 16), private_key=private_key, amount=amount
        )
        print(f"Deployed account: {address} with tx: {tx}")

        # Log the secret ID and corresponding address
        accounts_data.append(
            {"secret_name": secret_name, "secret_id": secret_id, "address": address}
        )

    return accounts_data


# %% Run
if __name__ == "__main__":
    # Number of accounts to create
    num_accounts = 30  # Number of accounts to create
    amount = 0.1  # Amount used to deploy all the accounts
    private_key = ""
    class_hash = "0x6153ccf69fd20f832c794df36e19135f0070d0576144f0b47f75a226e4be530"  # modify this with 0x061dac032f228abef9c6626f995015233097ae253a7f72d68552db02f2971b8f for sepolia

    # Deploy the accounts and store private keys in AWS Secrets Manager
    accounts_data = asyncio.run(
        deploy_accounts(num_accounts, amount, private_key, class_hash)
    )

    # Save the account data to a JSON file
    save_accounts_to_json(accounts_data)

    print(f"{num_accounts} accounts deployed and saved to 'oz_accounts.json'")
