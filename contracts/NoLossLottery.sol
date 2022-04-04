/// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NoLossLottery is AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    /// CONSTANTS

    /// VARIABLES
    /**
     *  @notice uint's used for storage
     *  lotteryFee is the fee for every lottery interest earned
     */
    uint public lotteryFee;

    /**
     *  @notice Variable used for store the address for pay the fees
     */
    address public recipientAddress;

    /**
     *  @notice Bytes32 used for roles
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// EVENTS

    /// MODIFIERS

    /// FUNCTIONS
    /**
     *  @notice Constructor function that initialice the contract
     */
    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(ADMIN_ROLE, msg.sender);

        setRecipientAddress(msg.sender);
        setlotteryFee(500);
    }

    /**
     *  @notice Set function that allows the admin to set the lottery fee
     *  @param _lotteryFee is a uint which will be the new lottery fee
     */
    function setlotteryFee(uint _lotteryFee) public onlyRole(ADMIN_ROLE) {
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
     *  @notice Function that allow to know if an address has the ADMIN_ROLE role
     *  @param _address is the address for check
     *  @return a boolean, true if the user has the ADMIN_ROLE role or false otherwise
     */
    function isAdmin(address _address) public view returns (bool) {
        return(hasRole(ADMIN_ROLE, _address));
    }
}