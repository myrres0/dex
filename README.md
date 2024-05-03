# Dex | CS251: Cryptocurrencies and Blockchain Technologies

Decentralized cryptocurrency exchange (DEX) and custom ERC20 token platform that has much of
the functionality possessed by full fledged decentralized exchanges such as Uniswap.

## Components

`contracts/token.sol` - ERC20 token contract

`contracts/exchange.sol` - Decentralized exchange contract modeled after Uniswap V1

`web_app/exchange.js` - client running locally in a web browser written in JavaScript.
It observes the blockchain using the ethers.js library and can calls functions in the smart
contracts token.sol and exchange.sol.

`test/Token.js` - tests for the ERC20 token contract

`test/Exchange.js` - tests for the decentralized exchange contract

## Compile and deploy

1. `npx hardhat node` - start a local Ethereum network
2. `npx hardhat run --network localhost scripts/deploy_token.js` - deploy the ERC20 token contract and then update token contract adress to `web_app/exchange.js` and `contracts/exchange.sol` 
3. `npx hardhat run --network localhost scripts/deploy_exchange.js` - deploy the decentralized exchange contract and then update exchange contract adress to `web_app/exchange.js`
4. open `web_app/index.html` in a web browser to interact with the contracts

## Tests

`npx hardhat test test/Token.js` - run tests for the ERC20 token

`npx hardhat test test/Exchange.js` - run tests for the decentralized exchange

`npx hardhat coverage` - The Hardhat Toolbox includes the solidity-coverage plugin to measure the test coverage in your project. 

`REPORT_GAS=true npx hardhat test` - The Hardhat Toolbox also includes the 
hardhat-gas-reporter plugin to get metrics of how much gas is used, based on the execution of your tests. The gas reporter is run when the test task is executed and the REPORT_GAS environment variable is set.
