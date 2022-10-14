<p align="center">
    <img src="resources/img/logo.png" height="200">
</p>
<div align="center">
  <h1 align="center">Kakarot</h1>
  <h3 align="center">EVM interpreter written in Cairo.</h3>
</div>

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/abdelhamidbakhta/kakarot/TESTS?style=flat-square&logo=github)
![GitHub](https://img.shields.io/github/license/abdelhamidbakhta/kakarot?style=flat-square&logo=github)
![GitHub contributors](https://img.shields.io/github/contributors/abdelhamidbakhta/kakarot?logo=github&style=flat-square)
![Lines of code](https://img.shields.io/tokei/lines/github/abdelhamidbakhta/kakarot?style=flat-square)
![Discord](https://img.shields.io/discord/595666850260713488?color=purple&logo=discord&style=flat-square)
![GitHub Repo stars](https://img.shields.io/github/stars/abdelhamidbakhta/kakarot?style=social)

<div align="center">

**Kakarot** is an Ethereum Virtual Machine written in Cairo. It means it can be deployed on StarkNet, a layer 2 scaling solution for Ethereum, and run an EVM bytecode program.
Hence, Kakarot can be used to run Ethereum smart contracts on StarkNet.
Kakarot is the ultimate ZK-EVM 🫶!
It is a work in progress, and it is not ready for production.

[Getting started](#%EF%B8%8F-getting-started) •
[Installation](#%F0%9F%A7%A9-installation) •
[Build](#%EF%B8%8F-build) •
[Test](#%EF%B8%8F-test)

</div>

## ⚙️ Getting started

![Tutorial](resources/img/kakarot.gif)

## 🧩 Installation

Install the requirements:

- [protostar](https://github.com/software-mansion/protostar)

Then, install the dependencies:

```bash
protostar install
```

## ⛏️ Build

```bash
protostar build
```

## 🌡️ Test

```bash
# Run all tests
protostar test

# Run only unit tests
protostar test tests/units

# Run only integration tests
protostar test tests/integrations
```

## 🐛 Debug

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

## Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/abdelhamidbakhta"><img src="https://avatars.githubusercontent.com/u/45264458?v=4?s=100" width="100px;" alt="Abdel @ StarkWare "/><br /><sub><b>Abdel @ StarkWare </b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=abdelhamidbakhta" title="Tests">⚠️</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=abdelhamidbakhta" title="Documentation">📖</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=abdelhamidbakhta" title="Code">💻</a> <a href="#infra-abdelhamidbakhta" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/LucasLvy"><img src="https://avatars.githubusercontent.com/u/70894690?v=4?s=100" width="100px;" alt="Lucas"/><br /><sub><b>Lucas</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=LucasLvy" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=LucasLvy" title="Tests">⚠️</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
