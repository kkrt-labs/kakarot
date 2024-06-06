# Contributing

When contributing to this repository, please first discuss the change you wish
to make via issue, before making a change. Please note we have a
[code of conduct](CODE_OF_CONDUCT.md), please follow it in all your interactions
with the project.

## Contributing guidelines

Kakarot is an open-source project and we welcome contributions of all kinds. However, we ask that you follow these guidelines when contributing:

- If you have an idea for a new feature or a bug fix, please create an issue first. This will allow us to discuss the idea and provide feedback before you start working on it.
- If you are working on an issue, please ask to be assigned. This will help us keep track of who is working on what and avoid duplicated work.
- Do not ask to be assigned to an issue if you are not planning to work on it immediately. We want to keep the project backlog clean and organized. If you are interested in working on an issue, please comment on the issue and we will assign it to you. We will remove the assignment if you do not start working on the issue within a 2 days. You can, of course, submit a draft PR if you need more time or have questions regarding the issue.
- Prefer rebasing over merging when updating your PR. This will keep the commit history clean and make it easier to review your changes.
- Adopt [conventional commit messages](https://www.conventionalcommits.org/en/v1.0.0/). This will help us when reviewing your PR.

## Prerequisites

To get started on Kakarot, you'll need python3.10, as well as Starknet-related
libraries, e.g. `cairo-lang`.

- Install [pyenv](https://github.com/pyenv/pyenv) to manage your Python versions (and don't forget to [setup your shell](https://github.com/pyenv/pyenv?tab=readme-ov-file#set-up-your-shell-environment-for-pyenv))
- Download the Python version used for Kakarot using pyenv: `pyenv install 3.10` and
- Install [poetry](https://python-poetry.org/docs/)
- Install [cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html) to manage our Rust dependencies

### Install docker

To build some experimental solidity contracts, you will need to have [docker installed](https://docs.docker.com/get-docker/).

### Install foundry

To assess the soundness of our EVM, we compile common Solidity contracts and run
tests on them through Kakarot.

To be able to verify and compare the ABI and bytecode of the Solidity test
contracts, first make sure you have
[foundry installed on your machine](https://book.getfoundry.sh/getting-started/installation).

### Install Scarb using asdf

We need to use Scarb to build Cairo contracts used as dependencies. As these dependencies rely on different versions of Cairo, you will need to install [scarb using asdf](https://docs.swmansion.com/scarb/download.html#install-via-asdf).
Once installed, you will need to install the following versions of Scarb:

```sh
asdf install scarb 0.7.0
asdf install scarb 2.6.4
```

### Install the VSCode extensions

- [Cairo Syntax](https://marketplace.visualstudio.com/items?itemName=starkware.cairo)
- [Cairo Language Server](https://marketplace.visualstudio.com/items?itemName=ericglau.cairo-ls)

## Setting up the environment

To set up a development environment, please follow these steps:

1. Clone the repo and navigate to it

   ```sh
   git clone https://github.com/kkrt-labs/kakarot && cd kakarot
   ```

2. Create and activate a virtual environment specifically for your Python project by running `poetry shell`.

3. Install dependencies

   ```sh
   make setup
   ```

4. Install katana

   ```sh
   make install-katana
   ```

5. Build the Solidity contracts

   ```sh
   make build-sol
   ```

6. Copy the default environment variables

   ```sh
   cp .env.example .env
   ```

7. Start a local katana instance

   ```sh
   make run-katana
   ```

8. Run tests

   ```sh
   make test
   ```

Common caveats:

- You will need to symlink `starknet-compile-deprecated` (new name of the
  starknet-compile binary) to `starknet-compile` in order to make the CairoLS
  VSCode extension work.

  ```bash
  ln -s <YOUR_PATH_TO_YOUR_PYTHON_VENV_BINARIES>/starknet-compile-deprecated <YOUR_PATH_TO_LOCAL_BINARIES>/starknet-compile
  # example: ln -s /Users/eliastazartes/code/kakarot/.venv/bin/starknet-compile-deprecated /usr/local/bin/starknet-compile
  ```

  If you followed the instructions above, you can run `poetry show cairo-lang -v` to find the path to your cairo-lang dependency, and the binaries should be in the `bin` directory.

- python3.10 is not compatible with the cairo-lang library. Make sure poetry and
  your pyenv are using the 3.10 version of Python. Your machine may have conflicting versions of python.
- Mac M1 chips are subject to some quirks/bugs with regards to some
  cryptographic libraries used by `cairo-lang`.
  - you may need to run `brew install gmp`.
  - if some c-compiler errors persist, refer to
    [this Cairo issue for solutions](https://github.com/OpenZeppelin/nile/issues/22).

## Issues and feature requests

You've found a bug in the source code, a mistake in the documentation or maybe
you'd like a new feature? You can help us by
[submitting an issue on GitHub](https://github.com/kkrt-labs/kakarot/issues/new/choose).
Before you create an issue, make sure to search the issue archive -- your issue
may have already been addressed!

Please try to create bug reports that are:

- _Reproducible._ Include steps to reproduce the problem.
- _Specific._ Include as much detail as possible: which version, what
  environment, etc.
- _Unique._ Do not duplicate existing opened issues.
- _Scoped to a Single Bug._ One bug per report.

**Even better: Submit a pull request with a fix or new feature!**

### How to submit a Pull Request

1. Search our repository for open or closed
   [Pull Requests](https://github.com/kkrt-labs/kakarot/pulls) that relate to
   your submission. You don't want to duplicate effort.
1. Fork the project
1. Create your feature branch (`git checkout -b feat/amazing_feature`)
1. Add, then commit your changes (`git commit -m 'feat: add amazing_feature'`)
1. Push to the branch (`git push origin feat/amazing_feature`)
1. [Open a Pull Request](https://github.com/kkrt-labs/kakarot/compare?expand=1)
