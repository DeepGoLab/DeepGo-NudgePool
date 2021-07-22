import { ethers } from "hardhat"
const { BigNumber } = require("ethers")

export const BASE_TEN = 10
export const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"

// Defaults to e18 using amount * 10^18
export function getBigNumber(amount: number, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals))
}

export function sleep(ms: number) {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve('');
    }, ms)
  });
}
