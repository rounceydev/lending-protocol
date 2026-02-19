// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @notice Interface for price oracles
 */
interface IPriceOracle {
    /**
     * @notice Returns the asset price in the base currency
     * @param asset The address of the asset
     * @return The price of the asset
     */
    function getAssetPrice(address asset) external view returns (uint256);

    /**
     * @notice Sets the price of an asset
     * @param asset The address of the asset
     * @param price The price of the asset
     */
    function setAssetPrice(address asset, uint256 price) external;
}
