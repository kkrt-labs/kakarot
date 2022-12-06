<p align="center">
    <img src="resources/img/kakarot_github_banner.png" height="200">
</p>
<div align="center">
  <h3 align="center">
  EVM interpreter written in Cairo, a sort of ZK-EVM emulator, leveraging STARK proof system.
  </h3>
</div>

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/abdelhamidbakhta/kakarot/TESTS?style=flat-square&logo=github)
![GitHub](https://img.shields.io/github/license/abdelhamidbakhta/kakarot?style=flat-square&logo=github)
![GitHub contributors](https://img.shields.io/github/contributors/abdelhamidbakhta/kakarot?logo=github&style=flat-square)
![GitHub top language](https://img.shields.io/github/languages/top/abdelhamidbakhta/kakarot?style=flat-square)
[![Telegram](https://img.shields.io/badge/telegram-Kakarot-yellow.svg?logo=telegram)](https://t.me/KakarotZkEvm)
![Contributions welcome](https://img.shields.io/badge/contributions-welcome-orange.svg)
[![Read FAQ](https://img.shields.io/badge/Ask%20Question-Read%20FAQ-000000)](https://www.newton.so/view?tags=kakarot)
![GitHub Repo stars](https://img.shields.io/github/stars/abdelhamidbakhta/kakarot?style=social)
[![Twitter Follow](https://img.shields.io/twitter/follow/KakarotZkEvm?style=social)](https://twitter.com/KakarotZkEvm)

<div align="center">

**Kakarot** is an Ethereum Virtual Machine written in Cairo. It means it can be
deployed on StarkNet, a layer 2 scaling solution for Ethereum, and run an EVM
bytecode program. Hence, Kakarot can be used to run Ethereum smart contracts on
StarkNet. Kakarot is the super sayajin ZK-EVM ! Why ? Because:
`It's over 9000!!!!!`. It is a work in progress, and it is not ready for
production.

[Getting started](#getting-started) • [Supported opcodes](#supported-opcodes) •
[Build](#build) • [Test](#test) •
[Report a bug](https://github.com/sayajin-labs/kakarot/issues/new?assignees=&labels=bug&template=01_BUG_REPORT.md&title=bug%3A+) • [Questions](https://www.newton.so/view?tags=kakarot)
</div>

![](resources/img/kakarot.gif)

## Supported opcodes

```mermaid
%%{init: {'theme': 'forest', 'themeVariables': { 'darkMode': 'false'}}}%%

pie title Kakarot EMV opcodes support (128 / 142)
    "Supported" : 128
    "Not supported" : 14
    "Partially supported" : 0
```

Here is the list of supported opcodes: [opcodes](docs/supported_opcodes.md)

For the moment the list is maintained manually, but it will likely be generated
automatically in the future. If you want to contribute, you can help us by
adding the missing opcodes. And if you implement a new opcode, please update the
list.

## Documentation

### Architecture

![](resources/img/architecture.png)

- ✅ Kakarot is a smart contract, deployed on Starknet (goerli). It is written
  in Cairo.

- ✅ Kakarot can: (a) execute arbitrary EVM bytecode, (b) deploy an EVM smart
  contract as is, (c) call a Kakarot-deployed EVM smart contract's functions
  (views and write methods).

- ✅ Kakarot is an EVM bytecode interpreter.

- ❌ Kakarot is not a blockchain

- ❌ Kakarot is not a compiler. Check out
  [Warp](https://github.com/NethermindEth/warp) for a Solidity -> Cairo
  transpiler

### Main execution flow

```mermaid
sequenceDiagram
    title Simple bytecode execution flow example: [PUSH1 0x01 PUSH1 0x02 ADD]
    actor User
    participant Kakarot
    participant ExecutionContext
    participant EVMInstructions
    participant ArithmeticOperations
    participant PushOperations
    participant Stack
    User->>+Kakarot: execute(value, code, calldata)
    Kakarot->>+EVMInstructions: generate_instructions()
    EVMInstructions->>-Kakarot: instructions
    Kakarot->>+ExecutionContext: compute_intrinsic_gas_cost()
    ExecutionContext->>-Kakarot: ctx
    Kakarot->>Kakarot: run(instructions, ctx)
    loop opcode
        Kakarot->>+EVMInstructions: decode_and_execute(instructions, ctx)
        EVMInstructions->>EVMInstructions: retrieve the current program counter
        Note over EVMInstructions: revert if pc < 0, stop if pc > length of code
        EVMInstructions->>EVMInstructions: read opcode associated function from instruction set
        Note over PushOperations, Stack: x2 PUSH a=1, PUSH b=2
        EVMInstructions->>+PushOperations: exec_push1(ctx)
        PushOperations->>Stack: push(stack, element)
        PushOperations->>-EVMInstructions: ctx
        EVMInstructions->>+ArithmeticOperations: exec_add(ctx)
        Note over PushOperations, Stack: x2 POP a, POP b
        ArithmeticOperations->>Stack: pop(stack)
        Stack->>ArithmeticOperations: element
        ArithmeticOperations->>Stack: push(stack, result)
        ArithmeticOperations->>-EVMInstructions: ctx
        EVMInstructions->>-Kakarot: ctx
    end
    Kakarot->>-User: ctx
```

### Execution sample

Execution of a simple EVM bytecode program on Kakarot.

The bytecode is the following:

```console
6001600503600301610166016002026105b40460020500
```

Which corresponds to the following EVM program:

```console
0x60 - PUSH1
0x60 - PUSH1
0x03 - SUB
0x60 - PUSH1
0x01 - ADD
0x61 - PUSH2
0x01 - ADD
0x60 - PUSH1
0x02 - MUL
0x61 - PUSH2
0x04 - DIV
0x60 - PUSH1
0x05 - SDIV
0x00 - STOP
```

Here is the execution trace of the program on Kakarot:

![Tutorial](resources/img/sample_execution.png)

## Installation

Install the requirements:

```bash
# install poetry if you don't have it already
# curl -sSL https://install.python-poetry.org | python3 -
make setup
```

For Mac M1s (using
[brew, miniforge and conda](https://towardsdatascience.com/how-to-easily-set-up-python-on-any-m1-mac-5ea885b73fab)):

```bash
brew install gmp
conda create --name cairo python=3.9
conda activate cairo
conda update -n base -c conda-forge conda
conda install pip
CFLAGS=-I`brew --prefix gmp`/include LDFLAGS=-L`brew --prefix gmp`/lib /opt/homebrew/Caskroom/miniforge/base/envs/cairo/bin/pip install ecdsa fastecdsa sympy
CFLAGS=-I`brew --prefix gmp`/include LDFLAGS=-L`brew --prefix gmp`/lib /opt/homebrew/Caskroom/miniforge/base/envs/cairo/bin/pip install cairo-lang cairo_coverage openzeppelin-cairo-contracts
```

## Build

```bash
make build
```

## Test

Running the tests requires to have docker available in the machine. Check
[their doc](https://docs.docker.com/get-docker/) for how to install it.

```bash
# Run all tests
make test

# Run only unit tests
make test-units

# Run only integration tests
make test-integration

# Run a specific test file
pytest <PATH_TO_FILE>  # with pytest
python3 -m unittest <PATH_TO_FILE>  # with unittest

# Run a specific test mark (markers in pyproject.toml)
make run-test-mark mark=<MARK>
make run-test-mark-log mark=<MARK> # with log
```

## Deploy

```bash
# On testnet
./scripts/deploy_kakarot.sh -p testnet -a admin
```

With:

- `testnet` profile defined in protostar config file (testnet for alpha-goerli)
- `admin` alias to the admin account (optional if it is your `__default__`
  account, see also starknet account
  [documentation](https://starknet.io/docs/hello_starknet/account_setup.html))

Contract addresses will be logged into the prompt.

### Inputs

To manage inputs sent to constructor during the deployment, you can customize
the [config files](./scripts/configs/).

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
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/abdelhamidbakhta"><img src="https://avatars.githubusercontent.com/u/45264458?v=4?s=100" width="100px;" alt="Abdel @ StarkWare "/><br /><sub><b>Abdel @ StarkWare </b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=abdelhamidbakhta" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=abdelhamidbakhta" title="Tests">⚠️</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=abdelhamidbakhta" title="Documentation">📖</a> <a href="#infra-abdelhamidbakhta" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#projectManagement-abdelhamidbakhta" title="Project Management">📆</a> <a href="#mentoring-abdelhamidbakhta" title="Mentoring">🧑‍🏫</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/LucasLvy"><img src="https://avatars.githubusercontent.com/u/70894690?v=4?s=100" width="100px;" alt="Lucas"/><br /><sub><b>Lucas</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=LucasLvy" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=LucasLvy" title="Tests">⚠️</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=LucasLvy" title="Documentation">📖</a> <a href="#mentoring-LucasLvy" title="Mentoring">🧑‍🏫</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/0xMentorNotAPseudo"><img src="https://avatars.githubusercontent.com/u/4404287?v=4?s=100" width="100px;" alt="Mentor Reka"/><br /><sub><b>Mentor Reka</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=0xMentorNotAPseudo" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=0xMentorNotAPseudo" title="Tests">⚠️</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=0xMentorNotAPseudo" title="Documentation">📖</a> <a href="#infra-0xMentorNotAPseudo" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/danilowhk"><img src="https://avatars.githubusercontent.com/u/12735159?v=4?s=100" width="100px;" alt="danilowhk"/><br /><sub><b>danilowhk</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=danilowhk" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=danilowhk" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://linktr.ee/lenny.codes"><img src="https://avatars.githubusercontent.com/u/46480795?v=4?s=100" width="100px;" alt="Lenny"/><br /><sub><b>Lenny</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=0xlny" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=0xlny" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/florian-bellotti"><img src="https://avatars.githubusercontent.com/u/7861901?v=4?s=100" width="100px;" alt="Florian Bellotti"/><br /><sub><b>Florian Bellotti</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=florian-bellotti" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=florian-bellotti" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/l-henri"><img src="https://avatars.githubusercontent.com/u/22731646?v=4?s=100" width="100px;" alt="Henri"/><br /><sub><b>Henri</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=l-henri" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=l-henri" title="Tests">⚠️</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/TotalPizza"><img src="https://avatars.githubusercontent.com/u/50166315?v=4?s=100" width="100px;" alt="FreshPizza"/><br /><sub><b>FreshPizza</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=TotalPizza" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=TotalPizza" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.linkedin.com/in/clementwalter"><img src="https://avatars.githubusercontent.com/u/18620296?v=4?s=100" width="100px;" alt="Clément Walter"/><br /><sub><b>Clément Walter</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=ClementWalter" title="Documentation">📖</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=ClementWalter" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/richwarner"><img src="https://avatars.githubusercontent.com/u/1719742?v=4?s=100" width="100px;" alt="Rich Warner"/><br /><sub><b>Rich Warner</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=richwarner" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=richwarner" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/pscott"><img src="https://avatars.githubusercontent.com/u/30843220?v=4?s=100" width="100px;" alt="pscott"/><br /><sub><b>pscott</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=pscott" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=pscott" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Eikix"><img src="https://avatars.githubusercontent.com/u/66871571?v=4?s=100" width="100px;" alt="Elias Tazartes"/><br /><sub><b>Elias Tazartes</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=Eikix" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=Eikix" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Riad15l"><img src="https://avatars.githubusercontent.com/u/116729712?v=4?s=100" width="100px;" alt="Riad15l"/><br /><sub><b>Riad15l</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=Riad15l" title="Code">💻</a> <a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=Riad15l" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/tyler-smith"><img src="https://avatars.githubusercontent.com/u/2145522?v=4?s=100" width="100px;" alt="Tyler Smith"/><br /><sub><b>Tyler Smith</b></sub></a><br /><a href="https://github.com/abdelhamidbakhta/kakarot/commits?author=tyler-smith" title="Tests">⚠️</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

## Questions / FAQ

Questions are welcome!
If you have any questions regarding Kakarot, feel free to ask them using [Newton](https://www.newton.so/view?tags=kakarot).

### FAQ
- [What is Kakarot, the zkEVM written in Cairo?](https://www.newton.so/view/6384d1e75bfa675b854c3228)
- [Is Kakarot zkEVM a blockchain?](https://www.newton.so/view/6384d22a5bfa675b854c3229)
- [When will Kakarot zkEVM launch on mainnet?](https://www.newton.so/view/6384d25fac8f7c40f4f144fd)
- [Does Kakarot zkEVM have a token?](https://www.newton.so/view/6384d2815bfa675b854c322a)
- [Is Kakarot zkEVM a smart contract or a blockchain?](https://www.newton.so/view/6384d2a0ac8f7c40f4f144fe)
- [Is Kakarot a Starkware project?](https://www.newton.so/view/6384d2be5bfa675b854c322b)
- [Is Kakarot part of the Starknet ecosystem?](https://www.newton.so/view#:~:text=Is%20Kakarot%20part%20of%20the%20Starknet%20ecosystem%3F)
- [Will Kakarot be an L3 on top of the Starknet validity rollup?](https://www.newton.so/view/6384d3235bfa675b854c322c)
- [Can I add Kakarot to my metamask?](https://www.newton.so/view/6384d38fac8f7c40f4f14500)
- [Is Kakarot equivalent to Arbitrum?](https://www.newton.so/view/6384d3d85bfa675b854c322d)

<p align="center">
    <img src="resources/img/kakarot_github_banner_footer.png" height="200">
</p>
