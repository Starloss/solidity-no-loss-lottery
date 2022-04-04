# solidity-nft-drop <br/>
An DApp created in Solidity with the funcionality of a No Loss Lottery in the Ethereum blockchain. <br/>
This project is for academic purposes only. <br/>
<br/>
Walkthrough: <br/>
<br/>
1- Clone the main branch into your local repository. <br/>
2- Open a terminal and navigate to the local repository. <br/>
3- Run the command "npm install" for installing all dependencies. <br/>
4- Create an .env file with 5 variables, "INFURA_URL", wich we will obtain the URL for deployment in Rinkeby, "PRIVATE_KEY" corresponding to your address private key. <br/>
"ALCHEMY_KEY" for the mainnet forking, ETHERSCAN_API_KEY for verify the contract if you deploy in some public net and COIN_MARKET_CAP_API_KEY for gas calculation in tests.<br/>
5- Run the script "compile" for compile the Hardhat project with Solidity 0.8.11. <br/>
6- Run the script "test" for start all tests for the project. <br/>
<br/>
Optional: <br/>
<br/>
7- You can run the script "deploy" for checking if the deploy is working. <br/>
8- You can run the script "coverage" for checking the stats of the tests. <br/>
9- You can run the script "verify" for verify the contract in the mainnet if this contract was deployed there. <br/>
<br/>