 module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const { address } = await deploy("NPSwap", {
    from: deployer,
    log: true,
    deterministicDeployment: false
  })
  console.log("NPSwap address: " + address)
}

module.exports.tags = ["NPSwap"]
