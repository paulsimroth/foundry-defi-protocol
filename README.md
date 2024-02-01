# DeFi Protocol with Stablecoin
  
## Intro

This is a project built with Foundry.
This project is meant to be a stablecoin where users can deposit WETH and WBTC in exchange for a token that will be pegged to the USD.
The main Contract is called DSCEngine.sol and it severves as the execution protocol of this project. Included is the DecentralizedStableCoin, which is a burnable ERC20 Token.

This system is designed to be as minimal as possible and have the Token maintain a peg of 1 Token == 1 US$
 
  This stablecoin has the properties:
  - Exogenous collateral
  - US Dollar pegging
  - Stabilization Algorithm

This system should always be over collateralized. At no point should the value of all collateral <= US$ backed value of all DSC

## Summary

1. Relative Stability, pegging to USD
   1. Chainlink Price Feed
   2. Function to exchange ETH & BTC -> USD
2. Stability Mechanism: Algorithmic
   1. Users can only mint with enough collateral (coded)
3. Collateral: Exogenous (Crypto)
   1. wETH
   2. wBTC
   
## Techstack

- Solidity (Programming Language)
- [Foundry](https://book.getfoundry.sh/) (Smart Contract Development Tool)
- [Chainlink-Pricefeeds](https://docs.chain.link/data-feeds/price-feeds) (Price Oracle)
- [Openzeppelin](https://www.openzeppelin.com/contracts) (Smart Contract Library)

## Foundry Documentation

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

Run local tests on Sepolia by forking
```shell
$ forge test --fork-url $SEPOLIA_RPC_URL
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
Anvil is Foundrys local dev blockchain
```shell
$ anvil
```

### Deploy

1. Setup environment variables
You'll want to set your SEPOLIA_RPC_URL and PRIVATE_KEY as environment variables. You can add them to a .env file, similar to what you see in .env.example.

 - PRIVATE_KEY: The private key of your account (like from metamask). NOTE: FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.You can learn how to export it here.
 - SEPOLIA_RPC_URL: This is url of the sepolia testnet node you're working with. You can get setup with one for free from Alchemy. Optionally, add your ETHERSCAN_API_KEY if you want to verify your contract on Etherscan.

2. Get testnet ETH
Head over to faucets.chain.link and get some testnet ETH. You should see the ETH show up in your metamask.

3. Deploy

```shell
$ forge script script/DeployDSC.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Cast

```shell
$ cast <subcommand>
```

## Thank you

If you found this useful, feel free to follow me or contact me!
<p align="left">

<a href="https://linkedin.com/in/paulsimroth" target="blank"><img align="center" src="https://raw.githubusercontent.com/rahuldkjain/github-profile-readme-generator/master/src/images/icons/Social/linked-in-alt.svg" alt="paulsimroth" height="30" width="40" /></a>

<a href="https://medium.com/@paul.simroth" target="blank"><img align="center" src="https://raw.githubusercontent.com/rahuldkjain/github-profile-readme-generator/master/src/images/icons/Social/medium.svg" alt="@paul.simroth" height="30" width="40" /></a>
</p>