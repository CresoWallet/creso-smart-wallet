
# CresoWallet: ERC-4337 Account Abstraction Implementation

  

This repository contains the implementation of `CresoWallet`, a smart contract designed for [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) account abstraction. ERC-4337 introduces a new standard for account abstraction in Ethereum, enabling more flexible account management and transaction handling without requiring changes to the Ethereum protocol.

  

## About ERC-4337

  

ERC-4337 is a proposal for account abstraction that allows for the creation of user accounts as smart contracts. These accounts can define custom rules for transaction validation, enabling features like recovery mechanisms, batched transactions, and more, all managed at the smart contract level. This proposal does not require any changes to the underlying Ethereum protocol and works within the existing framework.

  

## CresoWallet

  

`CresoWallet` is a smart contract implementation that leverages the ERC-4337 standard. It includes features such as:

  

- Guardian-based recovery process.

- Batched transaction execution.

- Customizable transaction validation logic.

- Enhanced security and user control over their accounts.

  

## Getting Started

  

### Prerequisites

  

Ensure you have [Node.js](https://nodejs.org/) and [npm](https://www.npmjs.com/) installed. This project uses [Hardhat](https://hardhat.org/), a popular development environment for Ethereum software.

  

### Installation

  

1. Clone the repository:

```sh
git clone https://github.com/CresoWallet/creso-smart-wallet

cd creso-smart-wallet
  ```
  

2. Install dependencies:

```sh

npm install

```

3. Running Tests

Run the tests to ensure everything is set up correctly:
  
```sh

npx hardhat test

 ``` 

4. Deployment

To deploy CresoWallet using Hardhat:

Create a .env file in the root directory and set up your Ethereum network and private key:

env
```sh
INFURA_API_KEY=your_infura_api_key
PRIVATE_KEY=your_private_key
```
Run the deployment script:
```sh

npx  hardhat  run  scripts/deploy.js  --network  your_network
```

Replace  your_network  with  the  Ethereum  network  you  wish  to  deploy  to (e.g., mainnet,  rinkeby,  ropsten).

  
  
  

# Resources

  

[Vitalik's post on account abstraction without Ethereum protocol changes](https://medium.com/infinitism/erc-4337-account-abstraction-without-ethereum-protocol-changes-d75c9d94dc4a)

  

[Discord server](http://discord.gg/fbDyENb6Y9)

  

[Bundler reference implementation](https://github.com/eth-infinitism/bundler)

  

[Bundler specification test suite](https://github.com/eth-infinitism/bundler-spec-tests)