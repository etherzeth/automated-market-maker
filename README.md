# Automated-Market-Maker (AMM) Project
This project is a demonstration of a Decentralized Exchange (DEX) built to showcase my expertise in developing secure, efficient, and well-structured smart contracts. It serves as a proof of concept highlighting my skills in blockchain development, decentralized finance (DeFi) mechanisms, and smart contract optimization.

These are the addresses of the contracts deployed on the Sepolia test network:

PoolRouter: 0x5FA42dFB2139F7461745a374fe76a7FeD53B1C4A
PoolFactory: 0xe82e77f6a81E5B0cC791bca298AbAEf60ad83a88


== Token ==

DAI     = 0x831fdB691F7b874a2a229dEe974430b9cB0FC044;

TWIZ    = 0x9C94dF046606595225958b0f17849F728b4D516C;

DWI     = 0x5F754c88836e4D9961676cb5b74732265960309B;

WETH    = 0xAbb972Fc416F7D3A8d7db748c5439238d051a099;

# Smart Contracts
1.LiquidityPool: This smart contract represents a generic liquidity pool.

2.PoolFactory: The pool factory manage and creates different liquidity pools.

3.PoolRouter: The router is the contract designed to interact with the pool factory and the liquidity pools.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

