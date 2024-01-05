# Contributing

When contributing to this repository, please first discuss the change you wish
to make via issue, before making a change. Please note we have a
[code of conduct](CODE_OF_CONDUCT.md), please follow it in all your interactions
with the project.

## Development environment setup

### Prerequisites

To get started on Kakarot, you'll need python3.9, as well as Starknet-related
libraries, e.g. `cairo-lang`.

- Install [poetry](https://python-poetry.org/docs/)
- Note you may need to run
  `curl -sSL https://install.python-poetry.org | python3.9 -` and not
  `curl -sSL https://install.python-poetry.org | python3 -` in order to force
  poetry to install itself on python3.9, just in case you have both python
  version 3.9 and 3.10 in your path.

#### Install foundry

To assess the soundness of our EVM, we compile common Solidity contracts and run
tests on them through Kakarot.

To be able to verify and compare the ABI and bytecode of the Solidity test
contracts, first make sure you have
[foundry installed on your machine](https://book.getfoundry.sh/getting-started/installation).

Then, run:

`make build-sol`

Common caveats:

- python3.10 is not compatible with the cairo-lang library. Make sure poetry and
  your pyenv are using the 3.9 version of Python. Your machine may have
  conflicting versions of python.
  - 3.9-dev will fail when running `make setup` since it is evaluated as 3.9.10+
    and therefore an invalid PEP 440 version (Poetry
    [enforces PEP 440 versioning](https://python-poetry.org/docs/faq#why-does-poetry-enforce-pep-440-versions)).
- Mac M1 chips are subject to some quirks/bugs with regards to some
  cryptographic libraries used by `cairo-lang`.
  - you may need to run `brew install gmp`.
  - if some c-compiler errors persist, refer to
    [this Cairo issue for solutions](https://github.com/OpenZeppelin/nile/issues/22).

To set up a development environment, please follow these steps:

1. Clone the repo

   ```sh
   git clone https://github.com/kkrt-labs/kakarot
   ```

2. Install dependencies

   ```sh
   make setup
   ```

3. Run tests

   ```sh
   make test
   ```

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
