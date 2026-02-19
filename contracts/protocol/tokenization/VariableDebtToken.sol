// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../interfaces/IDebtToken.sol";
import "../../interfaces/IPool.sol";
import "../../libraries/WadRayMath.sol";

/**
 * @title VariableDebtToken
 * @notice Variable debt token representing a variable-rate borrow in the lending protocol
 */
contract VariableDebtToken is ERC20, Ownable, Pausable, IDebtToken {
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
     * @notice Mints debt token to the `user` address
     */
    function mint(
        address user,
        uint256 amount,
        uint256 index
    ) external override onlyPool returns (bool) {
        uint256 previousBalance = _scaledBalances[user];
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, "INVALID_MINT_AMOUNT");

        _scaledTotalSupply += amountScaled;
        _scaledBalances[user] += amountScaled;

        uint256 actualAmount = amountScaled.rayMul(index).rayToWad();
        _mint(user, actualAmount);

        return previousBalance == 0;
    }

    /**
     * @notice Burns debt of `user`
     */
    function burn(
        address user,
        uint256 amount,
        uint256 index
    ) external override onlyPool {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, "INVALID_BURN_AMOUNT");

        _scaledTotalSupply -= amountScaled;
        _scaledBalances[user] -= amountScaled;

        uint256 actualAmount = amountScaled.rayMul(index).rayToWad();
        _burn(user, actualAmount);
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
    function balanceOf(address account) public view override(ERC20, IDebtToken) returns (uint256) {
        uint256 scaledBalance = _scaledBalances[account];
        if (scaledBalance == 0) {
            return 0;
        }
        uint256 normalizedDebt = IPool(POOL).getReserveNormalizedVariableDebt(
            UNDERLYING_ASSET_ADDRESS
        );
        return scaledBalance.rayMul(normalizedDebt).rayToWad();
    }

    /**
     * @notice Override totalSupply to return the actual supply with interest
     */
    function totalSupply() public view override returns (uint256) {
        uint256 normalizedDebt = IPool(POOL).getReserveNormalizedVariableDebt(
            UNDERLYING_ASSET_ADDRESS
        );
        return _scaledTotalSupply.rayMul(normalizedDebt).rayToWad();
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
