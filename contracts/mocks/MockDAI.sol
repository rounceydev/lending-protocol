// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

/**
 * @title MockDAI
 * @notice Mock DAI token for testing
 */
contract MockDAI is MockERC20 {
    constructor() MockERC20("Mock DAI", "mDAI", 18, 1000000 * 10**18) {}
}
