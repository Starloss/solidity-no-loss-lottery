const CONTRACT_NAME = "VRFCoordinatorV2Mock";

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Upgradeable Proxy
  await deploy("VRFCoordinatorV2Mock", {
    from: deployer,
    log: true,
  });
};

module.exports.tags = [CONTRACT_NAME];