# DeepGo-NudgePool
DeepGo NudgePool smart contracts

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
npm install --save-dev @uniswap/v2-core
npm install --save-dev @uniswap/v2-periphery
npm install --save-dev @openzeppelin/contracts
```
### 4.Compile
`npx hardhat compile`
### 5.Deploy
`npx hardhat deploy --network rinkeby`
### 6.Test
`npx hardhat test --network rinkeby`