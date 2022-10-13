<p align="center">
    <img src="resources/img/logo.png" height="200">
</p>
<div align="center">
  <h1 align="center">Kakarot</h1>
  <p align="center">
    <a href="https://github.com/abdelhamidbakhta/kakarot/actions">
        <img src="https://github.com/abdelhamidbakhta/kakarot/workflows/TESTS/badge.svg">
    </a>
  </p>
  <h3 align="center">EVM interpreter written in Cairo.</h3>
</div>

## ⚙️ Development

### 📦 Install the requirements

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

### 🐛 Debug

Start the debug server:

```bash
python3 tests/debug/debug_server.py
# then use DEBUG env variable
# for example:
DEBUG=True protostar test
```

## 🚀 Deployment

```bash
# On testnet
./scripts/deploy_kakarot.sh -p testnet -a admin
```

With:

- `testnet` profile defined in protostar config file (testnet for alpha-goerli)
- `admin` alias to the admin account (optional if it is your `__default__` acount, see also starknet account [documentation](https://starknet.io/docs/hello_starknet/account_setup.html))

Contract addresses will be logged into the prompt.

### Inputs

To manage inputs sent to constructor during the deployment, you can customize the [config files](./scripts/configs/).

## 📄 License

**kakarot** is released under the [MIT](LICENSE).
