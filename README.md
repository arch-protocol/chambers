[![Lint](https://github.com/arch-protocol/chambers/actions/workflows/CI.yml/badge.svg)](https://github.com/arch-protocol/chambers/actions/workflows/CI.yml)
[![Slither](https://github.com/arch-protocol/chambers/actions/workflows/slither.yml/badge.svg)](https://github.com/arch-protocol/chambers/actions/workflows/slither.yml)
[![Unit Tests](https://github.com/arch-protocol/chambers/actions/workflows/tests-unit.yml/badge.svg)](https://github.com/arch-protocol/chambers/actions/workflows/tests-unit.yml)
[![Chamber Integration](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-arch-chamber.yml/badge.svg)](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-arch-chamber.yml)
[![Issuer Integration](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-issuer-wizard.yml/badge.svg)](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-issuer-wizard.yml)
[![Rebalancer Integration](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-rebalance-wizard.yml/badge.svg)](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-rebalance-wizard.yml)
[![Fees Integration](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-streaming-fee-wizard.yml/badge.svg)](https://github.com/arch-protocol/chambers/actions/workflows/tests-int-streaming-fee-wizard.yml)

# Chambers 

This repository contains the core smart contracts for the Arch Chambers.

#### Full documentation [here](https://docs.arch.finance/chambers/)

## About Arch

Arch is a decentralized finance (DeFi) asset manager that enables passive investment in the decentralized (Web3) economy.

We curate a comprehensive family of market indices and tokenized products to help investors build and manage their Web3 portfolios. 

## Core contracts overview

The core contracts aim to create an ERC20 fungible product collateralized by other ERC20 tokens acting as an index capable of wrapping any token as long as they comply with the ERC20 standard.

### Chamber

A Chamber is a tokenized product collateralized by other ERC20 tokens. It's responsible for storing the data about the assets it holds and the proportion each represents.

The Chamber is also responsible for minting and burning new units. These functions are exposed to a set of Wizards accountable for validating the logic and adequately using the Chamber logic.

If the composition of the Chamber needs to be updated, developers can use Wizards to make trades using the underlying assets held by the Chamber.

### Issuer Wizard 

The Issuer Wizard is in charge of minting and redeeming tokens keeping the composition of underlying assets per unit constant. When tokens are minted or redeemed using this contract, the composition of the underlying assets per unit on the Chamber remains.

### Rebalancer Wizard

The Rebalancer Wizard allows rebalancing of the composition of underlying assets making a smart-contract transaction previously calculated off-chain. The target can be any contract as long as they're marked as allowed both in the wizard and in the Chamber God.

### Streaming Fee Wizard

The Streaming Fee Wizard takes advantage of the minting function of the Chamber to charge streaming fees. It's responsible for only collecting the proportion established for each Chamber.

### Chamber God

To create new chambers, developers need to use the Chamber God contract. Anyone can build a new Chamber and manage it on their own.

## Licensing

The primary license for Arch Chambers Core Contracts is Apache 2.0.


