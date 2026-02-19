// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle
 * @notice Simple price oracle for asset prices
 * @dev In production, this would integrate with Chainlink or other oracles
 */
contract PriceOracle is IPriceOracle, Ownable {
    mapping(address => uint256) private assetPrices;

    event AssetPriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Returns the asset price in the base currency (USD)
     */
    function getAssetPrice(address asset) external view override returns (uint256) {
        require(assetPrices[asset] > 0, "ASSET_NOT_FOUND");
        return assetPrices[asset];
    }

    /**
     * @notice Sets the price of an asset
     */
    function setAssetPrice(address asset, uint256 price) external override onlyOwner {
        require(price > 0, "INVALID_PRICE");
        uint256 oldPrice = assetPrices[asset];
        assetPrices[asset] = price;
        emit AssetPriceUpdated(asset, oldPrice, price);
    }

    /**
     * @notice Sets multiple asset prices at once
     */
    function setAssetPrices(
        address[] calldata assets,
        uint256[] calldata prices
    ) external onlyOwner {
        require(assets.length == prices.length, "INCONSISTENT_PARAMS");
        for (uint256 i = 0; i < assets.length; i++) {
            require(prices[i] > 0, "INVALID_PRICE");
            uint256 oldPrice = assetPrices[assets[i]];
            assetPrices[assets[i]] = prices[i];
            emit AssetPriceUpdated(assets[i], oldPrice, prices[i]);
        }
    }
}
