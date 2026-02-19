// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../interfaces/IAToken.sol";
import "../../interfaces/IPool.sol";
import "../../libraries/WadRayMath.sol";

/**
 * @title AToken
 * @notice Interest-bearing token representing a deposit in the lending protocol
 */
contract AToken is ERC20, ERC20Burnable, Ownable, Pausable, IAToken {
    using WadRayMath for uint256;

    address public immutable override UNDERLYING_ASSET_ADDRESS;
    address public immutable override POOL;

    uint256 internal _scaledTotalSupply;
    mapping(address => uint256) internal _scaledBalances;

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
     * @notice Mints aTokens to `user` and increases the total supply
     */
    function mint(address user, uint256 scaledAmount) external override onlyPool {
        _scaledTotalSupply += scaledAmount;
        _scaledBalances[user] += scaledAmount;

        uint256 amount = scaledAmount.rayToWad();
        _mint(user, amount);
    }

    /**
     * @notice Burns aTokens from `user` and decreases the total supply
     */
    function burn(address user, uint256 scaledAmount) external override onlyPool {
        _scaledTotalSupply -= scaledAmount;
        _scaledBalances[user] -= scaledAmount;

        uint256 amount = scaledAmount.rayToWad();
        _burn(user, amount);
    }

    /**
     * @notice Returns the scaled balance of the user
     */
    function scaledBalanceOf(address user) external view override returns (uint256) {
        return _scaledBalances[user];
    }

    /**
     * @notice Returns the scaled total supply
     */
    function scaledTotalSupply() external view override returns (uint256) {
        return _scaledTotalSupply;
    }

    /**
     * @notice Override balanceOf to return the actual balance with interest
     */
    function balanceOf(address account) public view override(ERC20, IERC20) returns (uint256) {
        uint256 scaledBalance = _scaledBalances[account];
        if (scaledBalance == 0) {
            return 0;
        }
        uint256 normalizedIncome = IPool(POOL).getReserveNormalizedIncome(UNDERLYING_ASSET_ADDRESS);
        return scaledBalance.rayMul(normalizedIncome).rayToWad();
    }

    /**
     * @notice Override totalSupply to return the actual supply with interest
     */
    function totalSupply() public view override returns (uint256) {
        uint256 normalizedIncome = IPool(POOL).getReserveNormalizedIncome(UNDERLYING_ASSET_ADDRESS);
        return _scaledTotalSupply.rayMul(normalizedIncome).rayToWad();
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
        super._update(from, to, value);
    }
}
