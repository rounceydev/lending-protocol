// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

/**
 * @title MockWETH
 * @notice Mock WETH token for testing
 */
contract MockWETH is MockERC20 {
    constructor() MockERC20("Mock Wrapped Ether", "mWETH", 18, 10000 * 10**18) {}
}
