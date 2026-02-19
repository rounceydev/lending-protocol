// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../interfaces/IDebtToken.sol";
import "../../interfaces/IPool.sol";

/**
 * @title StableDebtToken
 * @notice Stable debt token representing a stable-rate borrow in the lending protocol
 * @dev Simplified implementation - full implementation would track individual stable rates
 */
contract StableDebtToken is ERC20, Ownable, Pausable, IDebtToken {
    address public immutable override UNDERLYING_ASSET_ADDRESS;
    address public immutable override POOL;

    modifier onlyPool() {
        require(msg.sender == POOL, "CALLER_MUST_BE_POOL");
        _;
    }

    constructor(
        address pool,
        address underlyingAsset,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {
        POOL = pool;
        UNDERLYING_ASSET_ADDRESS = underlyingAsset;
    }

    /**
     * @notice Mints debt token to the `user` address
     * @dev Simplified - full implementation would track stable rates per user
     */
    function mint(
        address user,
        uint256 amount,
        uint256
    ) external override onlyPool returns (bool) {
        uint256 previousBalance = balanceOf(user);
        _mint(user, amount);
        return previousBalance == 0;
    }

    /**
     * @notice Burns debt of `user`
     */
    function burn(
        address user,
        uint256 amount,
        uint256
    ) external override onlyPool {
        _burn(user, amount);
    }

    /**
     * @notice Returns the scaled balance (same as balance for stable debt)
     */
    function scaledBalanceOf(address user) external view override returns (uint256) {
        return balanceOf(user);
    }

    /**
     * @notice Returns the scaled total supply (same as total supply for stable debt)
     */
    function scaledTotalSupply() external view override returns (uint256) {
        return totalSupply();
    }

    /**
     * @notice Pauses the token
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the token
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        require(to == address(0), "TRANSFER_NOT_ALLOWED");
        super._update(from, to, value);
    }
}
