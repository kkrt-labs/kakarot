# How to initialize Kakarot Environment to deploy Solidity Smart Contracts

## Objective

To get started, it's essential to learn the basics of how Kakarot works. Once you have a solid understanding, you can proceed to set up the environment for deploying Solidity smart contracts. By following a step-by-step process, you'll be able to create an environment that is conducive to efficient and effective smart contract deployment.
Overall, learning how to use Kakarot and setting up the environment for deploying Solidity smart contracts locally will greatly benefit your blockchain development efforts.

## What is Kakarot?

Kakarot is a zkEVM written in Cairo. This means that we can develop decentralized applications (dApps) using Solidity and leverage Ethereum ecosystem tools such as Hardhat, Foundry, Slither and Metamask.

The key differentiator is its scalability, which is provided by StarkNet.

## Let's start to Build

`In this tutorial We will run Kakarot with` [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers) `in our local machine`.

* Prerequisites:

  * [Git](https://git-scm.com/) installed.
  * [VS Code Dev Containers](ms-vscode-remote.remote-containers) installed.
  * [Basic understanding of docker](https://docs.docker.com/get-started/)
  * Basic knowledge of terminal to execute commands.

** If you prefer you can execute this repo directly in codespaces.
![Codespaces](../../img/codespaces.png)

### Step 1: Clone this repo

```bash
  git clone git@github.com:sayajin-labs/kakarot.git
```

### Step 2: Open the project in VS Code

Once the repository is cloned, let's open the project in VS Code.  
Then we will check some important files:

---(WIP)

* .devcontainer DIR contains a JSON file with the same name, this file describes how VS Code should start the container and what to do after it connects.

In this case we will use a container image with python3.9

```json
"image": "mcr.microsoft.com/vscode/devcontainers/python:0-3.9",
```

<p align="right">(<a href="https://code.visualstudio.com/docs/devcontainers/create-dev-container" target="_blank">See more</a>)
</p>

* scipts DIR
* Makefile
* pyproject.toml
