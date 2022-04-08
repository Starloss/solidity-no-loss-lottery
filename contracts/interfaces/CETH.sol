// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface CETH {
    function balanceOf(address) external view returns (uint256);

    function balanceOfUnderlying(address) external returns (uint);

    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);
}