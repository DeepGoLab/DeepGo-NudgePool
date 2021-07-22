module.exports = async function ({  deployments, getNamedAccounts }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    await deploy("IPStorage", {
      from: deployer,
      log: true,
      deterministicDeployment: false
    })

    await deploy("GPStorage", {
        from: deployer,
        log: true,
        deterministicDeployment: false
      })

    await deploy("LPStorage", {
        from: deployer,
        log: true,
        deterministicDeployment: false
      })

    await deploy("VaultStorage", {
        from: deployer,
        log: true,
        deterministicDeployment: false
      })
}

module.exports.tags = ["Storage"]
