module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const npswap = await ethers.getContract("NPSwap")

  await deploy("IPLogic", {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })

  await deploy("GPDepositLogic", {
    from: deployer,
    libraries: {"NPSwap": npswap.address},
    log: true,
    deterministicDeployment: false
  })

  await deploy("GPWithdrawLogic", {
    from: deployer,
    libraries: {"NPSwap": npswap.address},
    log: true,
    deterministicDeployment: false
  })

  await deploy("LPLogic", {
    from: deployer,
    libraries: {"NPSwap": npswap.address},
    log: true,
    deterministicDeployment: false
  })

  await deploy("VaultLogic", {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })

  await deploy("StateLogic", {
    from: deployer,
    libraries: {"NPSwap": npswap.address},
    log: true,
    deterministicDeployment: false
  })

  await deploy("LiquidationLogic", {
    from: deployer,
    libraries: {"NPSwap": npswap.address},
    log: true,
    deterministicDeployment: false
  })
}

module.exports.tags = ["Logic"]
module.exports.dependencies = ["NPSwap"]
