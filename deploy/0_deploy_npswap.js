 module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy("NPSwap", {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })
}

module.exports.tags = ["NPSwap"]
