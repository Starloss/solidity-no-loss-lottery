/// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./VRFConsumerBaseV2Upgradeable.sol";
import "./interfaces/CETH.sol";

import "hardhat/console.sol";

contract NoLossLottery is AccessControlUpgradeable, PausableUpgradeable, VRFConsumerBaseV2Upgradeable {
    /// CONSTANTS
    uint public constant TICKET_COST = 10000 gwei;

    address public constant COMPOUND_ETH_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// VARIABLES
    /**
     *  @notice bytes32's used for storage
     *  keyHash is the maximum gas price in wei for every request
     */
    bytes32 public keyHash;

    /**
     *  @notice uint's used for storage
     *  amountInvested is the amount of ether invested in the last lottery
     *  dateEndForNextLottery is the date which the actual lottery will ends
     *  dateStartForNextLottery is the date which the nect lottery will start
     *  lotteryFee is the fee for every lottery interest earned
     *  s_requestId is the ID of the request for random numbers
     *  totalOfTickets is the amount of tickets buyed in total
     *  s_subscriptionId is the asubscription ID for chainlink VRF V2
     *  callbackGasLimit is the max amount of gas for requesting the random numbers
     *  numWords is the amount of random numbers to be requested
     *  requestConfirmations is the amount of confirmations required for the random numbers
     */
    uint public amountInvested;
    uint public dateEndForNextLottery;
    uint public dateStartForNextLottery;
    uint public lotteryFee;
    uint public s_requestId;
    uint public totalOfTickets;
    uint64 public s_subscriptionId;
    uint32 public callbackGasLimit;
    uint32 public numWords;
    uint16 public requestConfirmations;

    /**
     *  @notice bool's used for storage
     *  winnerSelected is the boolean used for security
     *  @dev this bool prevents duplicated prices
     */
    bool public winnerSelected;

    /**
     *  @notice array's used for storage
     *  players is an array of Player used for store all active players
     *  s_randomWords is an array random numbers from VRF Chainlink
     */
    Player[] players;
    uint[] public s_randomWords;

    /**
     *  @notice Variable used for store external contracts
     */
    AggregatorV3Interface internal ETHFeed;
    LinkTokenInterface LINKTOKEN;
    VRFCoordinatorV2Interface COORDINATOR;

    /**
     *  @notice Variable used for store the address for pay the fees
     */
    address public recipientAddress;

    /// STRUCTS

    /**
     *  @notice Struct used for store the player and his ticketAmount
     */
    struct Player {
        address uid;
        uint tickets;
    }

    /// EVENTS

    /**
     *  @notice Event emmited when the contract reveives ETH without any data
     */
    event ETHReceived(
        uint amount,
        address sender
    );

    /**
     *  @notice Event emmited when a player buy tickets with ETH
     */
    event TicketsBuyedWithETH(
        uint amount,
        address buyer
    );

    /**
     *  @notice Event emmited when a player buy tickets with ERC20 tokens
     */
    event TicketsBuyedWithTokens(
        uint amount,
        address buyer
    );
    
    /**
     *  @notice Event emmited when the lottery starts and invest his funds
     */
    event FundsInvested(
        uint amount,
        uint nextEndDate
    );
    
    /**
     *  @notice Event emmited when a player retrieves his tickets
     */
    event TicketsRetrieved(
        uint amount,
        address player
    );

    /// MODIFIERS

    /**
     *  @notice Modifier function that verifies if the token is allowed
     *  @param token is the address of the token to be verified
     */
    modifier tokenAllowed(address token) {
        require(
            token == DAI_ADDRESS || token == USDC_ADDRESS || token == USDT_ADDRESS,
            "Token not allowed"
        );
        _;
    }

    /**
     *  @notice Modifier function that allows select the winner when 5 days have passed
     */
    modifier lotteryEnded() {
        require(block.timestamp >= dateEndForNextLottery, "Lottery has not ended");
        _;
    }
    
    /**
     *  @notice Modifier function that allows invest the funds when 2 days have passed
     */
    modifier lotteryReadyToStart() {
        require(block.timestamp >= dateStartForNextLottery, "Lottery it's not ready to start");
        _;
    }

    /**
     *  @notice Modifier function that prevents the user for buying tickets when
     *  @notice the lottery is already running
     */
    modifier ticketSaleOpen() {
        require(
            block.timestamp >= dateEndForNextLottery && block.timestamp <= dateStartForNextLottery,
            "Ticket sales are closed until this lottery ends"
        );
        _;
    }
    
    /**
     *  @notice Modifier function that prevents select more than 1 winner for the same price
     */
    modifier winnerNotSelected() {
        require(!winnerSelected, "Winner is already selected");
        _;
    }
    
    /**
     *  @notice Modifier function that prevents select the winner without a random number
     */
    modifier randomNumberRetrieved() {
        require(s_randomWords[0] != 0, "There is no random number yet");
        _;
    }
    
    /**
     *  @notice Modifier function that prevents select the winner without a random number
     */
    modifier randomNumberNoRequested() {
        require(s_requestId == 0, "There is a random number requested already");
        _;
    }

    /// FUNCTIONS
    /**
     *  @notice Constructor function that initialize the contract
     */
    function initialize(address vrfCoordinator) public initializer {
        __VRFConsumerBaseV2_init(vrfCoordinator);
        __AccessControl_init();
        __Pausable_init();

        _setupRole(ADMIN_ROLE, msg.sender);

        LINKTOKEN = LinkTokenInterface(LINK_ADDRESS);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);

        players.push(
            Player(msg.sender, 0)
        );

        setETHFeed(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        setRecipientAddress(msg.sender);
        setLotteryFee(500);

        winnerSelected = false;
        totalOfTickets = 0;
        dateStartForNextLottery = block.timestamp + 2 days;
        keyHash = 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805;
        callbackGasLimit = 100000;
        requestConfirmations = 3;
        numWords = 1;

        createNewSubscription();
    }

    fallback() external payable {
        console.log("fallback()");
        emit ETHReceived(msg.value, msg.sender);
    }

    receive() external payable {
        console.log("receive()");
        emit ETHReceived(msg.value, msg.sender);
    }

    /**
     *  @notice Function that allows the admin to request a random number from chainlink VRF V2
     *  @notice when this request get's fullfilled, the Coordinator will call fulfillRandomWords
     */
    function requestRandomWords() external onlyRole(ADMIN_ROLE) lotteryEnded randomNumberNoRequested {
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    /**
     *  @notice Function that allows  to supply the subscription with LINK
     *  @notice The subscription requires enough LINK for pay gas fee of retrieve random numbers
     *  @param amount is the amount of LINK for supply the subscription
     */
    function topUpSubscription(uint256 amount) external onlyRole(ADMIN_ROLE) {
        LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(s_subscriptionId));
    }

    /**
     *  @notice Function that allow to know the index of the player
     *  @param index is the uint to retrieve the information
     *  @return (address, uint) with the address and tickets of the player
     */
    function getPlayer(uint index) external view returns (address, uint) {
        return (players[index].uid, players[index].tickets);
    }

    /**
     *  @notice Function that allows buy tickets with ETH
     *  @notice if the user already have tickets, this increases the amount
     *  @notice if the user doesn't have any tickets, this create a new player with the amount
     *  @param amount is the amount of tickets for buy
     */
    function buyTicketsWithEth(uint amount) payable public ticketSaleOpen {
        require(msg.value >= amount * TICKET_COST, "Not enough amount");
        
        (bool success, ) = msg.sender.call{value: msg.value - (TICKET_COST * amount)}("");
        require(success, "Failed trying to return surplus ETH");

        if (isPlayer(msg.sender)) {
            players[playerIndex(msg.sender)].tickets += amount;
        } else {
            players.push(
                Player(msg.sender, amount)
            );
        }

        totalOfTickets += amount;

        emit TicketsBuyedWithETH(amount, msg.sender);
    }

    /**
     *  @notice Function that allows buy tickets with USDC, USDT or DAI tokens
     *  @notice This function uses Uniswap for swap between tokens and ETH
     *  @notice if the user already have tickets, this increases the amount
     *  @notice if the user doesn't have any tickets, this create a new player with the amount
     *  @param amount is the amount of tickets for buy
     *  @param _token is the address of the token used for buy the tickets
     */
    function buyTicketsWithToken(
        uint amount,
        address _token
    )
        public
        tokenAllowed(_token)
        ticketSaleOpen
    {
        ERC20 token = ERC20(_token);

        uint tokenCost = (TICKET_COST * uint(getETHPrice() * 10 ** 10)) / (10 ** 36) * (10 ** token.decimals());

        require(
            token.allowance(msg.sender, address(this)) >= amount * tokenCost,
            "Not enough tokens to buy these amounts of tickets"
        );

        token.transferFrom(msg.sender, address(this), amount * tokenCost);

        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS).WETH();

        IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS).swapExactTokensForETH(amount, 0, path, msg.sender, block.timestamp);

        if (isPlayer(msg.sender)) {
            players[playerIndex(msg.sender)].tickets += amount;
        } else {
            players.push(
                Player(msg.sender, amount)
            );
        }

        totalOfTickets += amount;

        emit TicketsBuyedWithTokens(amount, msg.sender);
    }

    /**
     *  @notice Function that allows invest all the ETH of the contract in compound
     *  @notice this function sets the end of the lottery in 5 days until the call of this function
     *  @notice also stores the amount of ETH invested for later calculations of interest gained
     */
    function invest() public lotteryReadyToStart {
        if (totalOfTickets == 0) {
            dateStartForNextLottery = block.timestamp + 2 days;
            return;
        }
        dateEndForNextLottery = block.timestamp + 5 days;
        amountInvested = address(this).balance;

        (bool success, ) = COMPOUND_ETH_ADDRESS.call{value: amountInvested}(abi.encodeWithSignature("mint()"));
        require(success);

        winnerSelected = false;

        emit FundsInvested(amountInvested, dateEndForNextLottery);
    }

    /**
     *  @notice Function that allows the users to retrieve his money
     *  @notice TICKET_COST is a constant, so the tickets always will have the same value
     *  @notice the recipientAddress it's not deleted from the game never
     *  @param _amount is the amount of tickets to retrieve in ETH
     */
    function retrieveTickets(uint _amount) public ticketSaleOpen {
        require(isPlayer(msg.sender), "You doesn't have any tickets");

        uint index = playerIndex(msg.sender);

        require(
            players[index].tickets >= _amount && _amount > 0,
            "You doesn't have sufficient tickets"
        );

        if (players[index].tickets == _amount && msg.sender != recipientAddress) {
            players[index] = players[players.length - 1];
            players.pop();
        } else {
            players[index].tickets -= _amount;
        }

        (bool success, ) = recipientAddress.call{value: _amount * TICKET_COST}("");
        require(success, "Failed trying sending the eth");

        totalOfTickets -= _amount;

        emit TicketsRetrieved(_amount, msg.sender);
    }

    /**
     *  @notice Set function that allows the admin to set the ETH feed address
     *  @param _address is an address which will be the new ETH feed address
     */
    function setETHFeed(address _address) public onlyRole(ADMIN_ROLE) {
        ETHFeed = AggregatorV3Interface(_address);
    }

    /**
     *  @notice Set function that allows the admin to set the lottery fee
     *  @param _lotteryFee is a uint which will be the new lottery fee
     */
    function setLotteryFee(uint _lotteryFee) public onlyRole(ADMIN_ROLE) {
        require(_lotteryFee >= 0 && _lotteryFee <= 1000, "Wrong fee!");

        lotteryFee = _lotteryFee;
    }

    /**
     *  @notice Set function that allows the admin to set the recipient address
     *  @notice this function will send all the ether in tickets to the recipient address
     *  @notice later, the player[0] will be the new recipientAddress
     *  @param _recipientAddress is the address which will be the new recipient address
     */
    function setRecipientAddress(address _recipientAddress) public onlyRole(ADMIN_ROLE) {
        if(players[0].tickets > 0) {
            uint amount = players[0].tickets * TICKET_COST;

            (bool success, ) = recipientAddress.call{value: amount}("");
            require(success, "Failed trying sending the eth");
        }

        players[0].tickets = 0;
        players[0].uid = _recipientAddress;
        
        recipientAddress = _recipientAddress;
    }
    
    /**
     *  @notice Set function that allows the admin to set the recipient address
     *  @param id is the uint which will be the new subscription ID
     */
    function setSubscriptionID(uint64 id) public onlyRole(ADMIN_ROLE) {
        s_subscriptionId = id;
    }

    /**
     *  @notice Function that allow to know if an address has the ADMIN_ROLE role
     *  @param _address is the address for check
     *  @return a boolean, true if the user has the ADMIN_ROLE role or false otherwise
     */
    function isAdmin(address _address) public view returns (bool) {
        return(hasRole(ADMIN_ROLE, _address));
    }
    
    /**
     *  @notice Function that allow to know if an address is a player
     *  @param _address is the address for check
     *  @return a boolean, true if the user is a player or false otherwise
     */
    function isPlayer(address _address) public view returns (bool) {
        for(uint i = 0; i < players.length; i++) {
            if (players[i].uid == _address) {
                return true;
            }
        }

        return false;
    }
    
    /**
     *  @notice Function that allow to know the index of the player
     *  @param _address is the address for check
     *  @return a uint, the index of the user
     */
    function playerIndex(address _address) public view returns (uint) {
        for(uint i = 0; i < players.length; i++) {
            if (players[i].uid == _address) {
                return i;
            }
        }

        revert("The user is not a player");
    }

    /**
     *  @notice Function called by the VRF V2 coordinator when gets the random number
     *  @param randomWords is the array which have the random numbers retrieved by chainlink VRF V2
     *  @dev the first parameter is not used, but is the space of the requestId
     */
    function fulfillRandomWords(
        uint256,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        console.log("1", s_randomWords[0]);
    }
    
    /**
     *  @notice Function that retrieves all the ETH invested and select a winner.
     *  @notice This function deposits all the prize as tickets
     */
    function getWinner() public onlyRole(ADMIN_ROLE) randomNumberRetrieved {
        winnerSelected = true;

        CETH cETH = CETH(COMPOUND_ETH_ADDRESS);
        
        uint numberOfTokens = cETH.balanceOfUnderlying(address(this));

        console.log("2", numberOfTokens);

        uint response = cETH.redeemUnderlying(numberOfTokens);

        console.log("2.1", response);
        console.log("2.2", address(this).balance);
        console.log("2.3", amountInvested);

        uint interest = address(this).balance - amountInvested;

        console.log("3", interest);

        uint ticketWinner = s_randomWords[0] % totalOfTickets + 1;
        uint winner;

        console.log("4", ticketWinner);

        for(uint i = 0; i < players.length; i++) {
            if(players[i].tickets >= ticketWinner) {
                winner = i;
                break;
            }

            ticketWinner -= players[i].tickets;
        }

        console.log("5", winner);

        uint interestPayedAsFee = (interest * lotteryFee) / 10000; /// 10000 = 100.00 %

        console.log("6", interestPayedAsFee);

        players[0].tickets += interestPayedAsFee / TICKET_COST;

        uint ticketsAsReward = (interest - interestPayedAsFee) / TICKET_COST;

        console.log("7", ticketsAsReward);

        players[winner].tickets += ticketsAsReward;
        totalOfTickets += ticketsAsReward;

        console.log("8", totalOfTickets);

        dateStartForNextLottery = block.timestamp + 2 days;
        s_randomWords[0] = 0;
        s_requestId = 0;
    }

    /**
     *  @notice Function that gets the price of ETH in USD using Chainlink
     *  @return an int with the price of ETH in USD with 10 decimals
     */
    function getETHPrice() internal view returns (int) {
        ( , int price, , , ) = ETHFeed.latestRoundData();
        return price;
    }

    /**
     *  @notice Function that creates a new subscription for chainlink VRF V2
     *  @dev this function doesn't send any LINK to the subscription
     *  @dev this has to made with the topUpSubscription function
     */
    function createNewSubscription() private onlyRole(ADMIN_ROLE) {
        // Create a subscription with a new subscription ID.
        address[] memory consumers = new address[](1);
        consumers[0] = address(this);
        s_subscriptionId = COORDINATOR.createSubscription();
        // Add this contract as a consumer of its own subscription.
        COORDINATOR.addConsumer(s_subscriptionId, consumers[0]);
    }
}