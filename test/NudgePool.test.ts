import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { getBigNumber, sleep } from "./utils";

describe("NudgePool", function () {
  before(async function () {
    const NPSwapAddress = "0x21a1106FdDB53FcF839811e83d3Eb112A169D1Ad";
    const NudgePoolAddress = "0xD9E434b98C9F21ab6B3630Ba3406b923B2641AE0";
    const NudgePoolStatusAddress = "0x4d7A456f2e61A8e5e41842d55FC0e9a3a0FEC5b3";

    this.token1 = "0xe09D4de9f1dCC8A4d5fB19c30Fb53830F8e2a047";
    this.token2 = "0xDA2E05B28c42995D0FE8235861Da5124C1CE81Dd";
    this.dgt = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE";

    this.signers = await ethers.getSigners();
    this.ipAccount1 = this.signers[1];
    this.ipAccount2 = this.signers[2];
    this.gpAccount1 = this.signers[3];
    this.gpAccount2 = this.signers[4];
    this.lpAccount1 = this.signers[5];
    this.lpAccount2 = this.signers[6];
    console.log("ipAccount1 address: " + this.ipAccount1.address);
    console.log("ipAccount2 address: " + this.ipAccount2.address);
    console.log("gpAccount1 address: " + this.gpAccount1.address);
    console.log("gpAccount2 address: " + this.gpAccount2.address);
    console.log("lpAccount1 address: " + this.lpAccount1.address);
    console.log("lpAccount2 address: " + this.lpAccount2.address);

    this.Token1 = await ethers.getContractAt('IERC20', this.token1);
    console.log("token1 address: " + this.Token1.address);
    this.Token2 = await ethers.getContractAt('IERC20', this.token2);
    console.log("token2 address: " + this.Token2.address);
    this.DGT = await ethers.getContractAt('IERC20', this.dgt);
    console.log("DGT address: " + this.DGT.address);

    this.NPSwap = await ethers.getContractAt('NPSwap', NPSwapAddress);
    console.log("NPSwap address: " + this.NPSwap.address);
    this.NudgePool = await ethers.getContractAt('NudgePool', NudgePoolAddress);
    console.log("NudgePool address: " + this.NudgePool.address);
    this.NudgePoolStatus = await ethers.getContractAt('NudgePoolStatus', NudgePoolStatusAddress);
    console.log("NudgePoolStatus address: " + this.NudgePoolStatus.address);
  })

  it("Create pool", async function () {
    const stage = await this.NudgePoolStatus.getPoolStage(this.token1, this.token2);
    // Return while not at finish stage
    if (stage != 0) {
      return
    }

    await this.Token1.connect(this.ipAccount1).approve(this.NudgePool.address, getBigNumber(10000));

    const createTX  = await this.NudgePool.connect(this.ipAccount1).createPool(
      this.ipAccount1.address,
      this.token1,
      this.token2,
      getBigNumber(10000),
      0,
      800000,
      1200000,
      100000,
      14400);
    await createTX.wait();

    // Expect right ip address
    expect(await this.NudgePoolStatus.getIPAddress(
      this.token1, this.token2)).to.be.equal(this.ipAccount1.address);
    // Expect at auction stage
    expect(await this.NudgePoolStatus.getPoolStage(
      this.token1, this.token2)).to.be.equal(2);
  })

  it("Auction pool", async function () {
    const stage = await this.NudgePoolStatus.getPoolStage(this.token1, this.token2);
    // Return while not at auction stage
    if (stage != 2) {
      return
    }

    await this.Token1.connect(this.ipAccount2).approve(this.NudgePool.address, getBigNumber(20000));
    await this.DGT.connect(this.ipAccount2).approve(this.NudgePool.address, getBigNumber(30));

    const auctionTx = await this.NudgePool.connect(this.ipAccount2).auctionPool(
      this.ipAccount2.address,
      this.token1,
      this.token2,
      getBigNumber(20000),
      getBigNumber(30)
    );
    await auctionTx.wait();

    // Expect right ip address
    expect(await this.NudgePoolStatus.getIPAddress(
      this.token1, this.token2)).to.be.equal(this.ipAccount2.address);
    // Expect right ip token amount
    expect(await this.NudgePoolStatus.getIPTokensAmount(
      this.token1, this.token2)).to.be.equal(getBigNumber(20000));
  })
  
  it("Check auction end", async function() {
    const stage = await this.NudgePoolStatus.getPoolStage(this.token1, this.token2);
    // Return while not at auction stage
    if (stage != 2) {
      return
    }

    // Wait to transit
    console.log("At auction stage and wait for rasing stage");
    let transit = await this.NudgePoolStatus.getStageTransit(
    this.token1, this.token2);
    while (transit == false) {
      await sleep(60000);
      transit = await this.NudgePoolStatus.getStageTransit(
        this.token1, this.token2);
    }
    console.log("Transit to rasing stage");

    const auctionEndTx = await this.NudgePool.connect(this.ipAccount2).checkAuctionEnd(
      this.token1,
      this.token2
    );
    await auctionEndTx.wait();

    // Expect at raising stage
    expect(await this.NudgePoolStatus.getPoolStage(
      this.token1, this.token2)).to.be.equal(3);
  })

  it("Check rasing end", async function() {
    const stage = await this.NudgePoolStatus.getPoolStage(this.token1, this.token2);
    // Return while not at rasing stage
    if (stage != 3) {
      return
    }

    // Wait to transit
    console.log("At raising stage and wait for running stage");
    let transit = await this.NudgePoolStatus.getStageTransit(
    this.token1, this.token2);
    while (transit == false) {
      await sleep(60000);
      transit = await this.NudgePoolStatus.getStageTransit(
        this.token1, this.token2);
    }
    console.log("Transit to running stage");

    const rasingEndTx = await this.NudgePool.connect(this.ipAccount2).checkRaisingEnd(
      this.token1,
      this.token2
    );
    await rasingEndTx.wait();

    // Expect at running stage
    expect(await this.NudgePoolStatus.getPoolStage(
      this.token1, this.token2)).to.be.equal(4);
  })

  it("Check ruuning end", async function() {
    const stage = await this.NudgePoolStatus.getPoolStage(this.token1, this.token2);
    // Return while not at ruuning stage
    if (stage != 4) {
      return
    }

    // Wait to transit
    console.log("At running stage and wait for finished stage");
    let transit = await this.NudgePoolStatus.getStageTransit(
    this.token1, this.token2);
    while (transit == false) {
      await sleep(60000);
      transit = await this.NudgePoolStatus.getStageTransit(
        this.token1, this.token2);
    }
    console.log("Transit to finished stage");

    const runningEndTx = await this.NudgePool.connect(this.ipAccount2).checkRunningEnd(
      this.token1,
      this.token2
    );
    await runningEndTx.wait();

    // Expect at finished stage
    expect(await this.NudgePoolStatus.getPoolStage(
      this.token1, this.token2)).to.be.equal(0);
  })
});
