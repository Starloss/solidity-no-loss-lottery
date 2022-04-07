/// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NoLossLottery is AccessControlUpgradeable, PausableUpgradeable {
    /// CONSTANTS
    address public constant compoundETHAddress = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public constant DAIAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDCAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDTAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// STRUCTS

    struct Player {
        address uid;
        uint tickets;
    }

    /// VARIABLES
    /**
     *  @notice uint's used for storage
     *  lotteryFee is the fee for every lottery interest earned
     *  dateEndForNextLottery is the date which the actual lottery will ends
     *  dateStartForNextLottery is the date which the nect lottery will start
     *  ticketCost is the cost in WEI of the tickets
     */
    uint public lotteryFee;
    uint public dateEndForNextLottery;
    uint public dateStartForNextLottery;
    uint public ticketCost;
    uint public amountInvested;
    uint public totalOfTickets;

    bool public winnerSelected;

    Player[] players;

    /**
     *  @notice Variable used for getting the feed price of ETH
     */
    AggregatorV3Interface internal ETHFeed;

    /**
     *  @notice Variable used for store the address for pay the fees
     */
    address public recipientAddress;

    /// EVENTS

    event ETHReceived(
        uint amount,
        address sender
    );

    event TicketsBuyedWithETH(
        uint amount,
        address buyer
    );

    event TicketsBuyedWithTokens(
        uint amount,
        address buyer
    );
    
    event FundsInvested(
        uint amount,
        uint nextEndDate
    );

    /// MODIFIERS

    modifier tokenAllowed(address token) {
        require(
            token == DAIAddress || token == USDCAddress || token == USDTAddress,
            "Token not allowed"
        );
        _;
    }

    modifier lotteryEnded() {
        require(block.timestamp >= dateEndForNextLottery, "Lottery has not ended");
        _;
    }
    
    modifier lotteryReadyToStart() {
        require(block.timestamp >= dateStartForNextLottery, "Lottery it's not ready to start");
        _;
    }

    modifier ticketSaleOpen() {
        require(block.timestamp >= dateEndForNextLottery && block.timestamp <= dateStartForNextLottery, "Ticket sales are closed until this lottery ends");
        _;
    }
    
    modifier winnerNotSelected() {
        require(!winnerSelected, "Winner is already selected");
        _;
    }

    /// FUNCTIONS
    /**
     *  @notice Constructor function that initialice the contract
     */
    function initialize() public initializer {
        __AccessControl_init();
        __Pausable_init();

        _setupRole(ADMIN_ROLE, msg.sender);

        setETHFeed(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        setRecipientAddress(msg.sender);
        setLotteryFee(500);
        setTicketCost(10000 gwei);

        winnerSelected = false;
        totalOfTickets = 0;
    }

    function buyATicketWithEth(uint amount) payable public ticketSaleOpen {
        require(msg.value >= amount * ticketCost);
        
        (bool success, ) = msg.sender.call{value: msg.value - (ticketCost * amount)}("");
        require(success, "Failed trying to return surplus ETH");

        if (isPlayer(msg.sender)) {
            players[playerIndex(msg.sender)].tickets += amount;
        } else {
            players.push(
                Player(msg.sender, amount)
            );
        }

        emit TicketsBuyedWithETH(amount, msg.sender);
    }

    function buyATicketWithToken(uint amount, address _token) public tokenAllowed(_token) ticketSaleOpen {
        ERC20 token = ERC20(_token);

        uint tokenCost = (ticketCost * uint(getETHPrice() * 10 ** 10)) / (10 ** 36) * (10 ** token.decimals());

        require(
            token.allowance(msg.sender, address(this)) >= amount * tokenCost,
            "Not enough tokens to buy these amounts of tickets"
        );

        token.transferFrom(msg.sender, address(this), amount * tokenCost);

        //swap

        if (isPlayer(msg.sender)) {
            players[playerIndex(msg.sender)].tickets += amount;
        } else {
            players.push(
                Player(msg.sender, amount)
            );
        }

        emit TicketsBuyedWithTokens(amount, msg.sender);
    }

    function invest() public lotteryReadyToStart {
        dateEndForNextLottery = block.timestamp + 5 days;
        amountInvested = address(this).balance;

        (bool success, ) = compoundETHAddress.call{value: amountInvested}(abi.encodeWithSignature("mint()"));
        require(success);

        winnerSelected = false;

        emit FundsInvested(amountInvested, dateEndForNextLottery);
    }

    function getWinner() public lotteryEnded winnerNotSelected {
        winnerSelected = true;
        
        (bool success, bytes memory returnData) = compoundETHAddress.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        require(success, "Failed trying getting the balance in compound");

        uint numberOfTokens = abi.decode(returnData, (uint));

        (success, ) = compoundETHAddress.call(abi.encodeWithSignature("redeem(uint256)", numberOfTokens));
        require(success, "Failed trying to redeem the Ether from compound");

        uint interest = address(this).balance - amountInvested;

        uint ticketWinner = 0; // Use chainling for get random number
        uint winner;

        for(uint i = 0; i < players.length; i++) {
            if(players[i].tickets >= ticketWinner) {
                winner = i;
                break;
            }

            ticketWinner -= players[i].tickets;
        }

        uint interestPayedAsFee = (interest * lotteryFee) / 10000; // 10000 = 100.00 %

        (success, ) = recipientAddress.call{value: interestPayedAsFee}("");
        require(success, "Fee recolection failed");

        uint ticketsAsReward = (interest - interestPayedAsFee) / ticketCost;

        players[winner].tickets += ticketsAsReward;
        totalOfTickets += ticketsAsReward;
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
     *  @param _recipientAddress is the address which will be the new recipient address
     */
    function setRecipientAddress(address _recipientAddress) public onlyRole(ADMIN_ROLE) {
        recipientAddress = _recipientAddress;
    }
    
    /**
     *  @notice Set function that allows the admin to set the ticket cost in ETH
     *  @param _ticketCost is the amount of WEI to be setted as the cost
     */
    function setTicketCost(uint _ticketCost) public onlyRole(ADMIN_ROLE) {
        ticketCost = _ticketCost;
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
     *  @notice Function that gets the price of ETH in USD using Chainlink
     *  @return an int with the price of ETH in USD with 10 decimals
     */
    function getETHPrice() internal view returns (int) {
        ( , int price, , , ) = ETHFeed.latestRoundData();
        return price;
    }

    receive() payable external {
        emit ETHReceived(msg.value, msg.sender);
    }
}