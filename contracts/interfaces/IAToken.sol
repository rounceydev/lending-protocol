// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IAToken
 * @notice Interface for the aToken contract
 */
interface IAToken is IERC20 {
    /**
     * @notice Returns the address of the underlying asset
     * @return The address of the underlying asset
     */
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    /**
     * @notice Returns the address of the pool
     * @return The address of the pool
     */
    function POOL() external view returns (address);

    /**
     * @notice Mints aTokens to `user` and increases the total supply
     * @param user The address receiving the aTokens
     * @param amount The amount of aTokens to mint
     */
    function mint(address user, uint256 amount) external;

    /**
     * @notice Burns aTokens from `user` and decreases the total supply
     * @param user The address whose aTokens will be burned
     * @param amount The amount of aTokens to burn
     */
    function burn(address user, uint256 amount) external;

    /**
     * @notice Returns the scaled balance of the user
     * @param user The address of the user
     * @return The scaled balance
     */
    function scaledBalanceOf(address user) external view returns (uint256);

    /**
     * @notice Returns the scaled total supply
     * @return The scaled total supply
     */
    function scaledTotalSupply() external view returns (uint256);
}
