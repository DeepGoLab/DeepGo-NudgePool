# DeepGo-NudgePool
DeepGo NudgePool smart contracts

https://deepgo.io/

## Introduction
Composed of three types of users, NudgePool fulfills the functions of the supply-demand match, resource allocation, and risk tranche.

**Three user types:**
* Initial Provider (IP): Project teams who need further financing and exposure
* Great Participant (GP): Investors who are risk-tolerant and strive for excess return
* Limit Participant (LP): Investors who are risk-averse and seek a stable return

**NudgePool Summary:**

During the Ongoing period, IPs act as asset suppliers, who impawn project tokens and provide investment bids; GPs screen projects and make investment decisions; LPs invest to leverage GPs.

**Operating process:**
1. IPs set impawn project token amount, LTV, Liquidation LTV, NudgePool period etc., to initiate NudgePool.
2. GPs are required to pay a purchase fee to join pools. Afterward, GPs' capital would be used to purchase project tokens from the DEX market, while a purchase fee will generate a Vault. Part of the Vault would be withdrawn by IPs as income.
3. The amount invested by LPs will be used to purchase project tokens and leverage GP. The remaining portion will be assigned to LPs as investment return.
4. During the Ongoing period, GPs and LPs can enter and exit pools in a permissionless manner. In addition, users can switch roles freely.
5. As the pool came to an end, IPs would withdraw pledged tokens, while GPs would sell the acquired tokens and return LPs their principal.
6. If the project token declined in price and triggers liquidation during Ongoing period, all tokens pledged by IPs would be given to GPs, who could only get back the remaining project tokens after returning the investment made by LPs.
![NudgePool](NudgePool.png)

## Development
### 1.Install hardhat
`npm install --save-dev hardhat`
### 2.Install hardhat-waffle and hardhat-ethers
`npm install --save-dev @nomiclabs/hardhat-waffle ethereum-waffle chai @nomiclabs/hardhat-ethers ethers`
### 3.Install dependency
```
npm install --save-dev ts-node typescript
npm install --save-dev chai @types/node @types/mocha @types/chai
npm install --save-dev mocha
npm install --save-dev dotenv
npm install --save-dev hardhat-preprocessor
npm install --save-dev hardhat-contract-sizer
npm install --save-dev hardhat-deploy
npm install --save-dev @nomiclabs/hardhat-ethers@npm:hardhat-deploy-ethers ethers
npm install --save-dev solidity-coverage
npm install --save-dev @tenderly/hardhat-tenderly
npm install --save-dev @uniswap/v2-core
npm install --save-dev @uniswap/v2-periphery
npm install --save-dev @openzeppelin/contracts
```
### 4.Compile
`npx hardhat compile`
### 5.Deploy
`npx hardhat deploy`
### 6.Test
`npx hardhat test`

## License
[MIT](LICENSE.txt)