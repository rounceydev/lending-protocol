// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDebtToken
 * @notice Interface for debt tokens (Variable and Stable)
 */
interface IDebtToken {
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
     * @notice Mints debt token to the `user` address
     * @param user The address receiving the borrowed amount
     * @param amount The amount of debt being minted
     * @param index The variable debt index of the reserve
     * @return `true` if the previous balance of the user is 0
     */
    function mint(
        address user,
        uint256 amount,
        uint256 index
    ) external returns (bool);

    /**
     * @notice Burns debt of `user`
     * @param user The address of the user getting his debt burned
     * @param amount The amount of debt tokens getting burned
     * @param index The variable debt index of the reserve
     */
    function burn(
        address user,
        uint256 amount,
        uint256 index
    ) external;

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

    /**
     * @notice Returns the principal balance of the user
     * @param user The address of the user
     * @return The principal balance
     */
    function balanceOf(address user) external view returns (uint256);
}
