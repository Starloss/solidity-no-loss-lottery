const CONTRACT_NAME = "NoLossLottery";

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  const coordinator = await get("VRFCoordinatorV2Mock");

  // Upgradeable Proxy
  await deploy("NoLossLottery", {
    from: deployer,
    proxy: {
      owner: deployer,
      execute: {
        init: {
          methodName: "initialize",
          args: [coordinator.address]
        },
      },
    },
    log: true,
  });
};

module.exports.tags = [CONTRACT_NAME];
module.exports.dependencies = ['VRFCoordinatorV2Mock']