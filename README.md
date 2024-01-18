<p align="center">
    <img src="docs/img/kakarot_github_banner.png" height="200">
</p>
<div align="center">
  <h3 align="center">
  zkEVM written in Cairo.
  proof system.
  </h3>
</div>

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/kkrt-labs/kakarot/ci.yml?branch=main)
![GitHub](https://img.shields.io/github/license/kkrt-labs/kakarot?style=flat-square&logo=github)
[![GitHub contributors](https://img.shields.io/github/contributors/kkrt-labs/kakarot?logo=github&style=flat-square)](https://github.com/kkrt-labs/kakarot/graphs/contributors)
![GitHub top language](https://img.shields.io/github/languages/top/kkrt-labs/kakarot?style=flat-square)
[![Telegram](https://img.shields.io/badge/telegram-Kakarot-yellow.svg?logo=telegram)](https://t.me/KakarotZkEvm)
![Contributions welcome](https://img.shields.io/badge/contributions-welcome-orange.svg)
![GitHub Repo stars](https://img.shields.io/github/stars/kkrt-labs/kakarot?style=social)
[![Twitter Follow](https://img.shields.io/twitter/follow/KakarotZkEvm?style=social)](https://twitter.com/KakarotZkEvm)
[![Discord](https://img.shields.io/discord/984015101017346058?color=%235865F2&label=Discord&logo=discord&logoColor=%23fff)](https://discord.gg/kakarotzkevm)

<div align="center">

Kakarot is an EVM implementation in Cairo. As such, it allows for provable
executions of EVM transactions, and is _de facto_ a so-called _zkEVM_. While
other zkEVM implementations (see for example
[Scroll](https://github.com/scroll-tech/zkevm-circuits),
[Polygon zkEVM](https://github.com/0xpolygonhermez) or
[Taiko](https://github.com/taikoxyz/taiko-geth)) try to prove existing EVM
implementations (mainly Geth), Kakarot is like another new Geth, but provable by
design, simply because it runs on the CairoVM.

Indeed, we strongly believe the CairoVM will provide the best zero-knowledge
toolbox in the coming years and that the Ethereum network effect will remain
prevalent in the meantime. We present to developers an abstraction layer they're
familiar with: the EVM. Build and deploy as if you were working on Ethereum, be
forward compatible with the future of zero-knowledge.

Kakarot is a work in progress, and it is not ready for production.

[Kakarot presentations and talks around the world](https://www.youtube.com/playlist?list=PLF3T1714MyKDwjjA8oHizXAdLNx62ka5U)

[Getting started](#getting-started) • [Supported opcodes](#supported-opcodes) •
[Build](#build) • [Test](#test) •
[Report a bug](https://github.com/kkrt-labs/kakarot/issues/new?assignees=&labels=bug&template=01_BUG_REPORT.md&title=bug%3A+)

</div>

## Supported opcodes

We support 100% of EVM [opcodes](docs/supported_opcodes.md) and 8 out of 9
precompiles.

## Documentation

### Architecture

- ✅ Kakarot is a set of Cairo programs

- ✅ Kakarot can be packaged as a smart contract and deployed on any chain that
  runs the CairoVM (currently only Starknet mainnet).

- ✅ Kakarot is an EVM implementation.

- ❌ Kakarot is not a blockchain by itself. It still needs a chain that runs the
  CairoVM to be deployed

- ❌ Kakarot is not a compiler.

## Getting started

To contribute, please check out
[the contribution guide](./docs/CONTRIBUTING.md).

The easiest way to get started is to use
[`devcontainers`](https://containers.dev/):

- either directly from GitHub to have an online VSCode with everything ready
  ![Codespaces](./docs/img/codespaces.png)
- or from VSCode, open the project and use "Dev Containers: Rebuild container"
  (requires Docker on your host machine)

Otherwise, you can proceed with a regular installation on your host:

```bash
# install poetry if you don't have it already
# curl -sSL https://install.python-poetry.org | python3 -
make setup
```

Note that you may need to symlink `starknet-compile-deprecated` (new name of the
starknet-compile binary) to `starknet-compile` in order to make the CairoLS
VSCode extension work:

```bash
ln -s <YOUR_PATH_TO_YOUR_PYTHON_VENV_BINARIES>/starknet-compile-deprecated <YOUR_PATH_TO_LOCAL_BINARIES>/starknet-compile
# example: ln -s /Users/eliastazartes/code/kakarot/.venv/bin/starknet-compile-deprecated /usr/local/bin/starknet-compile
```

## Build

To build the Cairo files:

```bash
make build
```

To build the test Solidity smart contracts:

```bash
# install foundry if you don't have it already
# curl -L https://foundry.paradigm.xyz | bash
# foundryup
make build-sol
```

## Code style

The project uses [trunk.io](https://trunk.io/) to run a comprehensive list of
linters.

To install Trunk, run:

```bash
curl https://get.trunk.io -fsSL | bash
```

You can also add Trunk to VSCode with
[this extension](https://marketplace.visualstudio.com/items?itemName=Trunk.io).

Then, don't forget to select Trunk as your default formatter in VSCode (command
palette > Format Document With > Trunk).

Once Trunk is installed, you can install a pre-push hook to run the linters
before each push:

```bash
trunk git-hooks sync
```

## Test

### Kakarot tests

Kakarot tests uses [pytest](https://docs.pytest.org/) as test runner. Make sure
to read the [doc](https://docs.pytest.org/) and get familiar with the tool to
benefit from all of its features.

```bash
# Run all tests
make test

# Run only unit tests
make test-units

# Run only integration tests
make test-integration

# Run a specific test file
pytest <PATH_TO_FILE>

# Run a specific test mark (markers in pyproject.toml)
pytest -m <MARK>
```

Test architecture is the following:

- tests/src contains cairo tests for each cairo function in the kakarot codebase
  running either in plain cairo or with the starknet test runner;
- tests/integration contains high level integrations tests running in the
  starknet test runner;
- tests/integration/end_to_end contains end-to-end tests running on an
  underlying Starknet-like network (using the Starknet RPC), currently
  [Katana](https://github.com/dojoengine/dojo). These end-to-end tests contain
  both raw bytecode execution tests and test on real solidity contracts.

The difference between the starknet test runner and the plain cairo one is that
the former emulate a whole starknet network and is as such much slower (~10x).

Consequently, when writing tests, don't use `%lang starknet` and contracts
unless it's really required.

For an example of the starknet test runner, see for example
[the Contract Account tests](tests/integration/accounts/test_contract_account.py).
For an example of the cairo test runner, see for example
[the RLP library tests](tests/src/utils/test_rlp.py). Especially, the cairo
runner uses hints to communicate values and return outputs:

- `kwargs` of `cairo_run` are available in the `program_input` variable
- values written in the `output` segment available in hints as a constant value
  are returned, e.g. `segments.write_arg(output, [ids.x])` will return the list
  `[x]`.

Both cairo and starknet tests can be used with the `--profile-cairo` flag to
generate a profiling file (see the `--profile_output` flag of the `cairo-run`
CLI). The file can then be used with `pprof`, for example:

```bash
go tool pprof --png <path_to_file.pb.gz>
```

The project also contains a regular forge project (`./solidity_contracts`) to
generate real artifacts to be tested against. This project also contains some
forge tests (e.g. `PlainOpcodes.t.sol`) which purpose is to test easily the
solidity functions meant to be tested with kakarot, i.e. quickly making sure
that they return the expected output so that we know that we focus on kakarot
testing and not .sol testing. They are not part of the CI. Simply use
`forge test` to run them.

### EF tests

To run the [Ethereum Foundation test suite](https://github.com/ethereum/tests),
you need to pull locally
[the Kakarot ef-tests runner](https://github.com/kkrt-labs/ef-tests). To
simplify the devX, you can create symlinks in the ef-tests repo pointing to your
local changes. For example:

```bash
ln -s /Users/clementwalter/Documents/kkrt-labs/kakarot/blockchain-tests-skip.yml blockchain-tests-skip.yml
mkdir build && cd build
ln -s /Users/clementwalter/Documents/kkrt-labs/kakarot/build/ v0
ln -s /Users/clementwalter/Documents/kkrt-labs/kakarot/build/fixtures/ common
```

With this setting, you can run a given EF test against your local Kakarot build
by running (in the ef test directory):

```bash
cargo test <test_name> --features v0 -- --nocapture
# e.g. cargo test test_sha3_d7g0v0_Shanghai --features v0 -- --nocapture
```

See [this doc](./docs/general/decode_a_cairo_trace.md) to learn how to debug a
cairo trace when the CairoVM reverts.

## Deploy

The following describes how to deploy the Kakarot as a Starknet smart contract.

It is **not** a description on how to deploy a solidity contract on the Kakarot
EVM.

The [deploy script](./scripts/deploy_kakarot.py) relies on some env variables
defined in a `.env` file located at the root of the project and loaded in the
[constant file](./scripts/constants.py). To get started, just

```bash
cp .env.example .env
```

The default file is self sufficient for using Kakarot with KATANA. If targeting
other networks, make sure to fill the corresponding variables.

Furthermore, if you want to run the
[check-resources](./scripts/check_resources.py) locally to check the steps usage
of your local changes in the EF tests against main and other branches, you need
to fill the following

```text
GITHUB_TOKEN=your_github_token
```

You can learn how to create this token from
[here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token),
we would suggest using a fine-grained token with only read access.

By default, everything will run on a local katana (started with
`make run-katana`). If you want to deploy to a given target, set the
`STARKNET_NETWORK` env variable, for example:

```bash
make deploy # localhost
STARKNET_NETWORK=testnet make deploy
STARKNET_NETWORK=mainnet make deploy
```

Deployed contract addresses will be stored in
`./deployments/{networks}/deployments.json`.

A step by step description of the individual components and how they are
deployed/configured can be found [here](docs/general/kakarot_components.md).

## License

**kakarot** is released under the [MIT](LICENSE).

## Security

Kakarot follows good practices of security, but 100% security cannot be assured.
Kakarot is provided **"as is"** without any **warranty**. Use at your own risk.

_For more information and to report security issues, please refer to our
[security documentation](docs/SECURITY.md)._

## Contributing

First off, thanks for taking the time to contribute! Contributions are what make
the open-source community such an amazing place to learn, inspire, and create.
Any contributions you make will benefit everybody else and are **greatly
appreciated**.

Please read [our contribution guidelines](docs/CONTRIBUTING.md), and thank you
for being involved!

## Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/abdelhamidbakhta"><img src="https://avatars.githubusercontent.com/u/45264458?v=4?s=100" width="100px;" alt="Abdel @ StarkWare "/><br /><sub><b>Abdel @ StarkWare </b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=abdelhamidbakhta" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=abdelhamidbakhta" title="Tests">⚠️</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=abdelhamidbakhta" title="Documentation">📖</a> <a href="#infra-abdelhamidbakhta" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#projectManagement-abdelhamidbakhta" title="Project Management">📆</a> <a href="#mentoring-abdelhamidbakhta" title="Mentoring">🧑‍🏫</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/LucasLvy"><img src="https://avatars.githubusercontent.com/u/70894690?v=4?s=100" width="100px;" alt="Lucas"/><br /><sub><b>Lucas</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=LucasLvy" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=LucasLvy" title="Tests">⚠️</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=LucasLvy" title="Documentation">📖</a> <a href="#mentoring-LucasLvy" title="Mentoring">🧑‍🏫</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/0xMentorNotAPseudo"><img src="https://avatars.githubusercontent.com/u/4404287?v=4?s=100" width="100px;" alt="Mentor Reka"/><br /><sub><b>Mentor Reka</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=0xMentorNotAPseudo" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=0xMentorNotAPseudo" title="Tests">⚠️</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=0xMentorNotAPseudo" title="Documentation">📖</a> <a href="#infra-0xMentorNotAPseudo" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/danilowhk"><img src="https://avatars.githubusercontent.com/u/12735159?v=4?s=100" width="100px;" alt="danilowhk"/><br /><sub><b>danilowhk</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=danilowhk" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=danilowhk" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://linktr.ee/lenny.codes"><img src="https://avatars.githubusercontent.com/u/46480795?v=4?s=100" width="100px;" alt="Lenny"/><br /><sub><b>Lenny</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=0xlny" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=0xlny" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/florian-bellotti"><img src="https://avatars.githubusercontent.com/u/7861901?v=4?s=100" width="100px;" alt="Florian Bellotti"/><br /><sub><b>Florian Bellotti</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=florian-bellotti" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=florian-bellotti" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/l-henri"><img src="https://avatars.githubusercontent.com/u/22731646?v=4?s=100" width="100px;" alt="Henri"/><br /><sub><b>Henri</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=l-henri" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=l-henri" title="Tests">⚠️</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/TotalPizza"><img src="https://avatars.githubusercontent.com/u/50166315?v=4?s=100" width="100px;" alt="FreshPizza"/><br /><sub><b>FreshPizza</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=TotalPizza" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=TotalPizza" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.linkedin.com/in/clementwalter"><img src="https://avatars.githubusercontent.com/u/18620296?v=4?s=100" width="100px;" alt="Clément Walter"/><br /><sub><b>Clément Walter</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=ClementWalter" title="Documentation">📖</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=ClementWalter" title="Tests">⚠️</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=ClementWalter" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/richwarner"><img src="https://avatars.githubusercontent.com/u/1719742?v=4?s=100" width="100px;" alt="Rich Warner"/><br /><sub><b>Rich Warner</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=richwarner" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=richwarner" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/pscott"><img src="https://avatars.githubusercontent.com/u/30843220?v=4?s=100" width="100px;" alt="pscott"/><br /><sub><b>pscott</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=pscott" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=pscott" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Eikix"><img src="https://avatars.githubusercontent.com/u/66871571?v=4?s=100" width="100px;" alt="Elias Tazartes"/><br /><sub><b>Elias Tazartes</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=Eikix" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=Eikix" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Riad-Quadratic"><img src="https://avatars.githubusercontent.com/u/116729712?v=4?s=100" width="100px;" alt="Riad-Quadratic"/><br /><sub><b>Riad-Quadratic</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=Riad-Quadratic" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=Riad-Quadratic" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/tyler-smith"><img src="https://avatars.githubusercontent.com/u/2145522?v=4?s=100" width="100px;" alt="Tyler Smith"/><br /><sub><b>Tyler Smith</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=tyler-smith" title="Tests">⚠️</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/spapinistarkware"><img src="https://avatars.githubusercontent.com/u/43779613?v=4?s=100" width="100px;" alt="Shahar Papini"/><br /><sub><b>Shahar Papini</b></sub></a><br /><a href="#mentoring-spapinistarkware" title="Mentoring">🧑‍🏫</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=spapinistarkware" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=spapinistarkware" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Riad-Quadratic"><img src="https://avatars.githubusercontent.com/u/116729712?v=4?s=100" width="100px;" alt="Riad &#124; Quadratic"/><br /><sub><b>Riad &#124; Quadratic</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=Riad-Quadratic" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/thomas-quadratic"><img src="https://avatars.githubusercontent.com/u/116874460?v=4?s=100" width="100px;" alt="thomas-quadratic"/><br /><sub><b>thomas-quadratic</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=thomas-quadratic" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.linkedin.com/in/pedro-bergamini-611496160/"><img src="https://avatars.githubusercontent.com/u/41773103?v=4?s=100" width="100px;" alt="Pedro Bergamini"/><br /><sub><b>Pedro Bergamini</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=pedrobergamini" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ptisserand"><img src="https://avatars.githubusercontent.com/u/544314?v=4?s=100" width="100px;" alt="ptisserand"/><br /><sub><b>ptisserand</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=ptisserand" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/hurrikaanig"><img src="https://avatars.githubusercontent.com/u/37303126?v=4?s=100" width="100px;" alt="TurcFort07"/><br /><sub><b>TurcFort07</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=hurrikaanig" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.linkedin.com/in/mnemba-chambuya"><img src="https://avatars.githubusercontent.com/u/22321030?v=4?s=100" width="100px;" alt="Mnemba Chambuya"/><br /><sub><b>Mnemba Chambuya</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=mnekx" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/matthieuauger"><img src="https://avatars.githubusercontent.com/u/1172099?v=4?s=100" width="100px;" alt="Matthieu Auger"/><br /><sub><b>Matthieu Auger</b></sub></a><br /><a href="#mentoring-matthieuauger" title="Mentoring">🧑‍🏫</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=matthieuauger" title="Tests">⚠️</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=matthieuauger" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ftupas"><img src="https://avatars.githubusercontent.com/u/35031356?v=4?s=100" width="100px;" alt="ftupas"/><br /><sub><b>ftupas</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=ftupas" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/jobez"><img src="https://avatars.githubusercontent.com/u/615197?v=4?s=100" width="100px;" alt="johann bestowrous"/><br /><sub><b>johann bestowrous</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=jobez" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://seshanth.xyz/"><img src="https://avatars.githubusercontent.com/u/35675963?v=4?s=100" width="100px;" alt="Seshanth.S"/><br /><sub><b>Seshanth.S</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=seshanthS" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://bezier.fi/"><img src="https://avatars.githubusercontent.com/u/66029824?v=4?s=100" width="100px;" alt="Flydexo"/><br /><sub><b>Flydexo</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=Flydexo" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=Flydexo" title="Tests">⚠️</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=Flydexo" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/petarcalic99"><img src="https://avatars.githubusercontent.com/u/47250382?v=4?s=100" width="100px;" alt="Petar Calic"/><br /><sub><b>Petar Calic</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=petarcalic99" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=petarcalic99" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/gaetbout"><img src="https://avatars.githubusercontent.com/u/16206518?v=4?s=100" width="100px;" alt="gaetbout"/><br /><sub><b>gaetbout</b></sub></a><br /><a href="#infra-gaetbout" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/greged93"><img src="https://avatars.githubusercontent.com/u/82421016?v=4?s=100" width="100px;" alt="greged93"/><br /><sub><b>greged93</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=greged93" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=greged93" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/FranFiuba"><img src="https://avatars.githubusercontent.com/u/5733366?v=4?s=100" width="100px;" alt="Francisco Strambini"/><br /><sub><b>Francisco Strambini</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=FranFiuba" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=FranFiuba" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/sparqet"><img src="https://avatars.githubusercontent.com/u/37338401?v=4?s=100" width="100px;" alt="sparqet"/><br /><sub><b>sparqet</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=sparqet" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=sparqet" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/omahs"><img src="https://avatars.githubusercontent.com/u/73983677?v=4?s=100" width="100px;" alt="omahs"/><br /><sub><b>omahs</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=omahs" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ArnaudBD"><img src="https://avatars.githubusercontent.com/u/20355199?v=4?s=100" width="100px;" alt="ArnaudBD"/><br /><sub><b>ArnaudBD</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=ArnaudBD" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.linkedin.com/in/dragan-pilipovic-78bb4712a/"><img src="https://avatars.githubusercontent.com/u/22306045?v=4?s=100" width="100px;" alt="Dragan Pilipovic"/><br /><sub><b>Dragan Pilipovic</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=dragan2234" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=dragan2234" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/bajpai244"><img src="https://avatars.githubusercontent.com/u/41180869?v=4?s=100" width="100px;" alt="Harsh Bajpai"/><br /><sub><b>Harsh Bajpai</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=bajpai244" title="Code">💻</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=bajpai244" title="Tests">⚠️</a> <a href="https://github.com/kkrt-labs/kakarot/commits?author=bajpai244" title="Documentation">📖</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/0xEniotna"><img src="https://avatars.githubusercontent.com/u/101047205?v=4?s=100" width="100px;" alt="Antoine"/><br /><sub><b>Antoine</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=0xEniotna" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Bal7hazar"><img src="https://avatars.githubusercontent.com/u/97087040?v=4?s=100" width="100px;" alt="Bal7hazar @ Carbonable"/><br /><sub><b>Bal7hazar @ Carbonable</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=Bal7hazar" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/dbejarano820"><img src="https://avatars.githubusercontent.com/u/58019353?v=4?s=100" width="100px;" alt="Daniel Bejarano"/><br /><sub><b>Daniel Bejarano</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=dbejarano820" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/JuMi231"><img src="https://avatars.githubusercontent.com/u/125477948?v=4?s=100" width="100px;" alt="JuMi231"/><br /><sub><b>JuMi231</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=JuMi231" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Jrigada"><img src="https://avatars.githubusercontent.com/u/62958725?v=4?s=100" width="100px;" alt="Juan Rigada"/><br /><sub><b>Juan Rigada</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=Jrigada" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/karasakalmt"><img src="https://avatars.githubusercontent.com/u/32202283?v=4?s=100" width="100px;" alt="Mete Karasakal"/><br /><sub><b>Mete Karasakal</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=karasakalmt" title="Documentation">📖</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/weiihann"><img src="https://avatars.githubusercontent.com/u/47109095?v=4?s=100" width="100px;" alt="Ng Wei Han"/><br /><sub><b>Ng Wei Han</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=weiihann" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/etashhh"><img src="https://avatars.githubusercontent.com/u/112415316?v=4?s=100" width="100px;" alt="etash"/><br /><sub><b>etash</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=etashhh" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/kasteph"><img src="https://avatars.githubusercontent.com/u/3408478?v=4?s=100" width="100px;" alt="kasteph"/><br /><sub><b>kasteph</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=kasteph" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Kelvyne"><img src="https://avatars.githubusercontent.com/u/8125532?v=4?s=100" width="100px;" alt="Lakhdar Slaim"/><br /><sub><b>Lakhdar Slaim</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=Kelvyne" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/mmsc2"><img src="https://avatars.githubusercontent.com/u/88055861?v=4?s=100" width="100px;" alt="mmsc2"/><br /><sub><b>mmsc2</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=mmsc2" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/sarantapodarousa"><img src="https://avatars.githubusercontent.com/u/75222483?v=4?s=100" width="100px;" alt="sarantapodarousa"/><br /><sub><b>sarantapodarousa</b></sub></a><br /><a href="https://github.com/kkrt-labs/kakarot/commits?author=sarantapodarousa" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

<p align="center">
    <img src="docs/img/kakarot_github_banner_footer.png" height="200">
</p>
