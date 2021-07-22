module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    const ipstorage = await ethers.getContract("IPStorage")
    const gpstorage = await ethers.getContract("GPStorage")
    const lpstorage = await ethers.getContract("LPStorage")
    const vaultstorage = await ethers.getContract("VaultStorage")

    let DGTBenifit = "0xc16Fcf982d2A3623fFb2704F77453d6f9d438C0E"
    let DGT = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE"

    const chainId = await getChainId()
    if (chainId === '1') {
        DGT = "0xc8eec1277b84fc8a79364d0add8c256b795c6727"

    } else if (chainId === '3') {
        DGT = "0x689a4FBAD3c022270caBD1dbE2C7e482474a70bc"
        DGTBenifit = deployer

    } else if (chainId === '4') {
        DGT = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE"
        DGTBenifit = deployer
    }

    await deploy("NudgePool", {
        from: deployer,
        args: [DGT, DGTBenifit, ipstorage.address, gpstorage.address, lpstorage.address, vaultstorage.address],
        log: true,
        deterministicDeployment: false
    })
    const nudgepool = await ethers.getContract("NudgePool")

    await deploy("NudgePoolStatus", {
        from: deployer,
        args: [ipstorage.address, gpstorage.address, lpstorage.address, vaultstorage.address, nudgepool.address],
        log: true,
        deterministicDeployment: false
    })

    await ipstorage.setProxy(nudgepool.address)
    await gpstorage.setProxy(nudgepool.address)
    await lpstorage.setProxy(nudgepool.address)
    await vaultstorage.setProxy(nudgepool.address)

    await nudgepool.setDuration(
        300,
        300,
        600
    )

    const iplogic =  await ethers.getContract("IPLogic")
    const gpdepositlogic = await ethers.getContract("GPDepositLogic")
    const gpwithdrawlogic = await ethers.getContract("GPWithdrawLogic")
    const lplogic = await ethers.getContract("LPLogic")
    const vaultlogic = await ethers.getContract("VaultLogic")
    const statelogic = await ethers.getContract("StateLogic")
    const liquidationlogic = await ethers.getContract("LiquidationLogic")
    await nudgepool.initialize( iplogic.address, gpdepositlogic.address, gpwithdrawlogic.address,
                lplogic.address, vaultlogic.address, statelogic.address, liquidationlogic.address)
}

module.exports.tags = ["NudgePool"]
module.exports.dependencies = ["Storage", "Logic"]
