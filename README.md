# Hadron Vault Infrastructure (Unus Nullus UAB)

This repository contains Hadron — the Unus Nullus UAB vault infrastructure: an appropriate, modular ERC4626-based system for
general-purpose vaults. It enables automated on-chain asset management via pluggable integrations ("fuses") while
keeping the core minimal and protocol-agnostic.

## Technical Overview

For architecture details and usage guides, refer to the docs in this repository.

## Installation

To install the dependencies for this project:

```bash
npm install
```

This will install all the required Node.js packages listed in [package.json](./package.json).

## Smart Contract Development

This project uses Foundry for Ethereum smart contract development. To get started with Foundry:

1. Install Foundry by following [Foundry's installation guide](https://getfoundry.sh/).
2. Build the smart contracts using:

```bash
forge build
```

## Testing

To run smart contract tests, you need to set up a `.env` file with the required environment variables.

### Environment Variables
An example `.env` file is in [.env.example](./.env.example). Copy this file to `.env` and fill in the required values.

- `ETHEREUM_PROVIDER_URL` - Ethereum provider URL
- `ARBITRUM_PROVIDER_URL` - Arbitrum provider URL
- `BASE_PROVIDER_URL` - Base provider URL
- `TAC_PROVIDER_URL` - TAC provider URL
- `INK_PROVIDER_URL` - Ink provider URL

Test smart contracts using:

```bash
forge test -vvv --ffi
```

## Pre-commit hooks

### requirements

- Python 3.11.6
- Node.js 20.17.0

### install pre-commit

use instruction from https://pre-commit.com/

#### install pre-commit

- `pip install pre-commit`
- `pre-commit install`

## Workflows

This repository includes several GitHub Actions workflows located in `.github/workflows/`:

- **CI Workflow** (`ci.yml`): Runs continuous integration tasks.
- **CD Workflow** (`cd.yml`): Manages continuous deployment processes.

## License

For more details, see the [LICENSE](./LICENSE) file.
