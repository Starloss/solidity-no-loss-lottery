const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");
const { ethers, waffle, deployments, getNamedAccounts } = require("hardhat");

describe("NoLossLottery", () => {
    let NoLossLottery;
    let owner, Alice, Bob;
    
    beforeEach(async () => {
        await deployments.fixture(['NoLossLottery']);
        let {deployer, user1, user2} = await getNamedAccounts();
        owner = await ethers.getSigner(deployer);
        Alice = await ethers.getSigner(user1);
        Bob = await ethers.getSigner(user2);
        NoLossLottery = await ethers.getContract('NoLossLottery', owner);
    });

    describe("Deploy", () => {
        it("Should set the variable correct", async () => {
        });
    });

    describe("NoLossLottery functions", () => {
    });
});
