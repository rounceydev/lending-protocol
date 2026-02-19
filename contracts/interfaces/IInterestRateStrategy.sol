// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IInterestRateStrategy
 * @notice Interface for interest rate calculation strategies
 */
interface IInterestRateStrategy {
    /**
     * @notice Calculates the interest rates depending on the reserve's state and configurations
     * @param reserve The address of the reserve
     * @param liquidityAdded The liquidity added during the operation
     * @param liquidityTaken The liquidity taken during the operation
     * @param totalStableDebt The total borrowed from the reserve at a stable rate
     * @param totalVariableDebt The total borrowed from the reserve at a variable rate
     * @param averageStableBorrowRate The weighted average of all the stable rate loans
     * @param reserveFactor The reserve portion of the interest that goes to the treasury
     * @return The liquidity rate
     * @return The stable borrow rate
     * @return The variable borrow rate
     */
    function calculateInterestRates(
        address reserve,
        uint256 liquidityAdded,
        uint256 liquidityTaken,
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 averageStableBorrowRate,
        uint256 reserveFactor
    ) external view returns (uint256, uint256, uint256);
}
