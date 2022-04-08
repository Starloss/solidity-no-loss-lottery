const web3 = require('web3');
const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");
const { ethers, waffle, deployments, getNamedAccounts } = require("hardhat");

const provider = ethers.provider;

const LINKAddress = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
const LINKABI = [{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"},{"name":"_data","type":"bytes"}],"name":"transferAndCall","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_subtractedValue","type":"uint256"}],"name":"decreaseApproval","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_addedValue","type":"uint256"}],"name":"increaseApproval","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"remaining","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"},{"indexed":false,"name":"data","type":"bytes"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"owner","type":"address"},{"indexed":true,"name":"spender","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Approval","type":"event"}];

describe("NoLossLottery", () => {
    let NoLossLottery, VRFCoordinatorV2Mock;
    let owner, Alice, Bob;
    
    beforeEach(async () => {
        await deployments.fixture(['NoLossLottery']);
        let {deployer, user1, user2} = await getNamedAccounts();
        owner = await ethers.getSigner(deployer);
        Alice = await ethers.getSigner(user1);
        Bob = await ethers.getSigner(user2);
        NoLossLottery = await ethers.getContract('NoLossLottery', owner);
        VRFCoordinatorV2Mock = await ethers.getContract('VRFCoordinatorV2Mock', owner);
    });

    describe("Deploy", () => {
        it("Should set the variable correct", async () => {
            expect(await NoLossLottery.isAdmin(owner.address)).to.be.equal(true);

            let [uid, tickets] = await NoLossLottery.getPlayer(0);

            expect(uid).to.be.equal(owner.address);
            expect(tickets).to.be.equal(0);
            expect(await NoLossLottery.lotteryFee()).to.be.equal(500);
            expect(await NoLossLottery.recipientAddress()).to.be.equal(owner.address);
            expect(await NoLossLottery.winnerSelected()).to.be.equal(false);
            expect(await NoLossLottery.totalOfTickets()).to.be.equal(0);
            expect(await NoLossLottery.keyHash()).to.be.equal("0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805");
            expect(await NoLossLottery.callbackGasLimit()).to.be.equal(100000);
            expect(await NoLossLottery.requestConfirmations()).to.be.equal(3);
            expect(await NoLossLottery.numWords()).to.be.equal(1);
        });
    });

    describe("NoLossLottery functions", () => {
        it("Should work in the principal workflow", async() => {
            // This piece of code it's needed when we are testing with the real VRF Coordinator
            // But in this tests, we are using a Mock which doesn't need LINK

            // const LINKContract = await hre.ethers.getContractAt(LINKABI, LINKAddress);
            // await hre.network.provider.request({
            //     method: "hardhat_impersonateAccount",
            //     params: ["0x5a52E96BAcdaBb82fd05763E25335261B270Efcb"],
            // });
            // const LINKOwner = await ethers.getSigner("0x5a52E96BAcdaBb82fd05763E25335261B270Efcb");

            // await LINKContract.connect(LINKOwner).transfer(NoLossLottery.address, parseEther("1000"));
            // await NoLossLottery.topUpSubscription(parseEther("1000"));

            // It's a little bit confusing how to get the balance of a subscription with the Coordinator

            let subID = await NoLossLottery.s_subscriptionId();

            await VRFCoordinatorV2Mock.fundSubscription(subID, parseEther("10000"));

            const ticketCost = await NoLossLottery.TICKET_COST();

            await NoLossLottery.connect(Alice).buyTicketsWithEth(100000, {value: parseEther("1")});

            let [AliceUID, AliceTickets] = await NoLossLottery.getPlayer(1);
            expect(AliceUID).to.be.equal(Alice.address);
            expect(AliceTickets).to.be.equal(100000);

            await NoLossLottery.connect(Bob).buyTicketsWithEth(900000, {value: parseEther("9")});

            let [BobUID, BobTickets] = await NoLossLottery.getPlayer(2);
            expect(BobUID).to.be.equal(Bob.address);
            expect(BobTickets).to.be.equal(900000);

            await network.provider.send("evm_increaseTime", [172800]);
            await network.provider.send("evm_mine");

            await NoLossLottery.invest();

            expect(await provider.getBalance(NoLossLottery.address)).to.be.equal(0);

            await expect(
                NoLossLottery
                .connect(owner)
                .buyTicketsWithEth(100000, {value: parseEther("1")})
            )
            .to
            .be
            .revertedWith("Ticket sales are closed until this lottery ends");

            await network.provider.send("evm_increaseTime", [432000]);
            await hre.network.provider.send("hardhat_mine", ["0x81CE"]);

            await NoLossLottery.requestRandomWords();
            let requestId = await NoLossLottery.s_requestId();
            
            await VRFCoordinatorV2Mock.fulfillRandomWords(requestId, NoLossLottery.address);
            
            console.log(await provider.getBalance(NoLossLottery.address));

            const transactionHash = await owner.sendTransaction({
                to: NoLossLottery.address,
                value: ethers.utils.parseEther("1.0"), // Sends exactly 1.0 ether
            });

            console.log("Ether sended");
            console.log(await provider.getBalance(NoLossLottery.address));

            await NoLossLottery.getWinner();

            let [uid, tickets] = await NoLossLottery.getPlayer(0);
            [AliceUID, AliceTickets] = await NoLossLottery.getPlayer(1);
            [BobUID, BobTickets] = await NoLossLottery.getPlayer(2);
            console.log(tickets.toNumber());
            console.log(AliceTickets.toNumber());
            console.log(BobTickets.toNumber());
        });
    });
});
