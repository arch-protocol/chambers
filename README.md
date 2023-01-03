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

We curate a comprehensive family of market indices and tokenized products and help investors build and manage their Web3 portfolios. In other words, Arch is Blackrock and Wealthfront for Web3. We are a small team committed to pooling capital on Web3.

## Core contracts overview

The objective of the following contracts is to create an ERC20 fungible product, that act as an index or ETF, capable of wrapping any token as long as they are compliant with ERC20 standard.

### Chamber

A chamber is an index or ETF by itself. It is responsible for handling ERC20 logic like minting and burning tokens, but more importantly, save the data about which assets it holds and the proportion of them on each unit of the chamber token. This contract holds the assets. 

In order to update the inner states of a Chamber, Wizards there are different contracts from the core that can be used.

### Issuer Wizard 

This contract is the one in charge of the mint/redeem operations of the Chamber. There's no way to mint or redeem a Chamber token directly using the Chamber contract.

### Rebalancer Wizard

Like every other index or ETF, the composition of it may need changes. With the rebalancer, the underlying assets can be traded for others in order to change the composition of the chamber. Trades and composition changes can only be performed using this contract.

### Streaming Fee Wizard

The main objective of the Streaming Fee wizard is to give the ability of charge fees of any chamber. This creates a little of inflation (creating supply). It's configured by the managers of the Chamber. This is the only way a manager of a Chamber can charge fees using the core contracts. 

## Licensing
The primary license for Arch Chambers core contracts is Apache 2.0

