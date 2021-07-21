module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const npswap = await ethers.getContract("NPSwap")

  const { address } = await deploy("GPDepositLogic", {
    from: deployer,
    libraries: {"NPSwap": npswap.address},
    log: true,
    deterministicDeployment: false
  })
  console.log("GPDepositLogic address: " + address)
}

module.exports.tags = ["Logic"]
module.exports.dependencies = ["NPSwap"]
