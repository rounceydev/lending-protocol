// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing
 */
contract MockUSDC is MockERC20 {
    constructor() MockERC20("Mock USDC", "mUSDC", 6, 1000000 * 10**6) {}
}
