import "dotenv/config"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-ethers"
import "hardhat-deploy"
import "hardhat-contract-sizer"
import "@tenderly/hardhat-tenderly"

require("./task/rollback.ts")

import { HardhatUserConfig } from "hardhat/types"

const accounts = {
  mnemonic: process.env.MNEMONIC || "test test test test test test test test test test test junk",
}

const config: HardhatUserConfig = {
  defaultNetwork: "rinkeby",
  networks: {
    hardhat: {
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      gasPrice: 120 * 1000000000,
      chainId: 1,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 3,
      gasPrice: 5000000000,
      gasMultiplier: 2,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.OWNER_PRIVATE_KEY}`,
        `${process.env.IP1_PRIVATE_KEY}`,
        `${process.env.IP2_PRIVATE_KEY}`,
        `${process.env.GP1_PRIVATE_KEY}`,
        `${process.env.GP2_PRIVATE_KEY}`,
        `${process.env.LP1_PRIVATE_KEY}`,
        `${process.env.LP2_PRIVATE_KEY}`],
      chainId: 4,
      gas: 12450000,
      gasPrice: 8000000000,
      gasMultiplier: 2,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    dev: {
      default: 1,
    },
  },
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    deploy: "deploy",
    deployments: "deployments",
    imports: "imports",
    sources: "contracts",
    tests: "test",
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  mocha: {
    timeout: 18000000
  }
}

export default config
