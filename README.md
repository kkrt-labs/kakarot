<div align="center">
  <h1 align="center">Zkairvm</h1>
  <p align="center">
    <a href="https://twitter.com/intent/follow?screen_name=dimahledba">
        <img src="https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white">
    </a>       
  </p>
  <h3 align="center">EVM interpreter written in Cairo.</h3>
</div>

## Usage

> ## ⚠️ WARNING! ⚠️
>
> This is repo contains highly experimental code.
> Expect rapid iteration.
> **Use at your own risk.**

### Set up the project

#### 📦 Install the requirements

- [protostar](https://github.com/software-mansion/protostar)

### 🎉 Install

```bash
protostar install
```

### ⛏️ Compile

```bash
protostar build
```

### 🌡️ Test

```bash
# Run all tests
protostar test

# Run only unit tests
protostar test tests/units

# Run only integration tests
protostar test tests/integrations
```

## 🚀 Deployment

```bash
# On testnet
./scripts/deploy_zkairvm.sh -p testnet -a admin
```

With:

- `testnet` profile defined in protostar config file (testnet for alpha-goerli)
- `admin` alias to the admin account (optional if it is your `__default__` acount, see also starknet account [documentation](https://starknet.io/docs/hello_starknet/account_setup.html))

Contract addresses will be logged into the prompt.

### Inputs

To manage inputs sent to constructor during the deployment, you can customize the [config files](./scripts/configs/).

## 📄 License

**zkairvm** is released under the [MIT](LICENSE).
